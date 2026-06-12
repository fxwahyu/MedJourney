//
//  FoundationModelsService.swift
//  MedJourney
//

import Foundation
import FoundationModels

/// Result of on-device journal pre-processing.
/// `cleanedContent` is what gets forwarded to the cloud — raw user text stays on-device.
struct JournalPreProcessingResult {
    let isUrgent: Bool
    let urgentKeywords: [String]
    let extractedSymptoms: [String]
    let cleanedContent: String
}

/// On-device AI via Apple Foundation Models — private, free, no network.
///
/// Acts as the privacy layer of the AI pipeline: raw journal text is processed
/// here first, and only cleaned/structured output ever reaches a cloud LLM.
final class FoundationModelsService {

    static let shared = FoundationModelsService()

    /// Cached inference result. `SystemLanguageModel.availability` can report
    /// `.available` even when model assets aren't downloaded (common in the
    /// simulator), so the first `GenerationError -1` marks the model unavailable
    /// for the rest of the session to avoid repeated failing calls.
    ///
    /// `nil` = untested, `true` = inference confirmed working, `false` = unavailable.
    nonisolated(unsafe) private var inferenceConfirmed: Bool?

    private init() {
        if case .unavailable = SystemLanguageModel.default.availability {
            inferenceConfirmed = false
        }
    }

    var isAvailable: Bool {
        if inferenceConfirmed == false { return false }
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    /// Caches unavailability after a `GenerationError -1` (model assets missing).
    /// Positive codes (guardrails, unsupported language) are per-request and must
    /// not mark the model permanently unavailable.
    private func handleInferenceError(_ error: Error) {
        let nsError = error as NSError
        if nsError.domain.contains("GenerationError") && nsError.code == -1 {
            inferenceConfirmed = false
        }
    }

    // MARK: - Journal Pre-Processing

    /// Analyzes journal text on-device before anything is sent to the cloud:
    /// detects urgent red-flag language, extracts symptoms, and strips noise.
    /// Falls back to the original text untouched when the model is unavailable.
    func preProcessJournalEntry(_ text: String) async -> JournalPreProcessingResult {
        let fallback = JournalPreProcessingResult(
            isUrgent: false, urgentKeywords: [], extractedSymptoms: [], cleanedContent: text
        )

        guard isAvailable,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return fallback
        }

        let prompt = """
        Analyze this health journal entry. Return ONLY a valid JSON object (no markdown fences, no extra text):

        {
          "is_urgent": true or false,
          "urgent_keywords": ["list any red-flag phrases found, or empty array"],
          "symptoms": ["list specific symptoms, body complaints, or feelings mentioned"],
          "cleaned_text": "rewrite keeping only medically relevant content; remove greetings, filler words, and off-topic sentences"
        }

        Set is_urgent to true ONLY if the text contains any of: chest pain, can't breathe, difficulty breathing, sudden numbness, blurry vision, stroke, seizure, severe headache, loss of consciousness, uncontrollable bleeding, can't move arm or leg.

        Journal text to analyze:
        \(text)
        """

        do {
            let response = try await LanguageModelSession().respond(to: prompt)
            inferenceConfirmed = true
            return parsePreProcessingResult(from: response.content, originalText: text)
        } catch {
            handleInferenceError(error)
            return fallback
        }
    }

    private func parsePreProcessingResult(from raw: String, originalText: String) -> JournalPreProcessingResult {
        guard let data = Self.stripFences(raw).data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return JournalPreProcessingResult(
                isUrgent: false, urgentKeywords: [], extractedSymptoms: [], cleanedContent: originalText
            )
        }
        return JournalPreProcessingResult(
            isUrgent: obj["is_urgent"] as? Bool ?? false,
            urgentKeywords: obj["urgent_keywords"] as? [String] ?? [],
            extractedSymptoms: obj["symptoms"] as? [String] ?? [],
            cleanedContent: obj["cleaned_text"] as? String ?? originalText
        )
    }

    // MARK: - Home Welcome Insight

    /// Generates the two-sentence daily briefing for the home screen from local
    /// health context. Returns nil when the model is unavailable or context is empty.
    func generateWelcomeInsight(
        recentTags: [String],
        anomalyMessages: [String],
        yesterdayCompletion: Double?,
        daysSinceLastEntry: Int?,
        healthContext: String? = nil
    ) async -> String? {
        guard isAvailable else { return nil }

        var lines: [String] = []
        if let healthContext,
           !healthContext.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           !healthContext.contains("No recent health context") {
            lines.append("Documented health context:\n\(healthContext)")
        }
        if let days = daysSinceLastEntry {
            lines.append(days == 0
                ? "User logged a health entry today."
                : "Last health journal was \(days) day\(days == 1 ? "" : "s") ago.")
        }
        if !recentTags.isEmpty {
            lines.append("Recent health patterns: \(recentTags.prefix(5).joined(separator: ", ")).")
        }
        if let pct = yesterdayCompletion {
            lines.append("Yesterday's health checklist was \(Int(pct * 100))% completed.")
        }
        if !anomalyMessages.isEmpty {
            lines.append("Vitals alert: \(anomalyMessages.first ?? "")")
        }
        guard !lines.isEmpty else { return nil }

        let prompt = """
        You are MedCare AI, a warm health companion. Write a short daily briefing of EXACTLY TWO sentences (about 30–40 words total) that checks in on the user.

        Structure:
        - Sentence 1: warmly name the user's SPECIFIC recent situation — cite a concrete detail from the context (a recent symptom like the dizziness, a lab trend like improving blood sugar, or how their week went).
        - Sentence 2: a brief, useful takeaway — gentle encouragement, one small thing to keep an eye on, or a nudge worth acting on today. Make it feel personal and actionable, not generic.

        Rules:
        - Be specific to THIS user. A generic "hope you're well" is a failure.
        - You MAY mention the user's already-documented conditions/trends (their known history, not a new diagnosis).
        - Do NOT invent any NEW medical condition. Warm and supportive, never alarming or clinical.

        User's health context:
        \(lines.joined(separator: "\n"))

        Write only the two sentences, nothing else.
        """

        do {
            let response = try await LanguageModelSession().respond(to: prompt)
            inferenceConfirmed = true
            let result = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return result.isEmpty ? nil : result
        } catch {
            handleInferenceError(error)
            return nil
        }
    }

    // MARK: - Insight Phrasing

    /// Phrases pre-calculated tag frequency counts as a 1–2 sentence insight.
    /// Input is locally computed stats only — no raw journal entries involved.
    func phraseTagInsight(tagCounts: [String: Int], periodLabel: String) async -> String? {
        guard isAvailable, !tagCounts.isEmpty else { return nil }

        let top = tagCounts
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { "\($0.key) (\($0.value) times)" }
            .joined(separator: ", ")

        let prompt = """
        You are MedCare AI. Turn these symptom-observation statistics into 1–2 warm, plain-English sentences for a health app user.

        Statistics for the past \(periodLabel):
        \(top)

        Rules:
        - Warm and encouraging tone, never alarming
        - Describe frequencies and patterns only — do NOT name or suggest any medical condition or diagnosis
        - Use observational phrasing: "you've been mentioning X often" not "this could mean you have X"
        - No medical jargon, no bullet points
        - Max 2 sentences total

        Write only the insight sentences, nothing else.
        """

        do {
            let response = try await LanguageModelSession().respond(to: prompt)
            inferenceConfirmed = true
            let result = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return result.isEmpty ? nil : result
        } catch {
            handleInferenceError(error)
            return nil
        }
    }

    // MARK: - Helpers

    private static func stripFences(_ raw: String) -> String {
        raw.replacingOccurrences(of: "```json", with: "")
           .replacingOccurrences(of: "```", with: "")
           .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
