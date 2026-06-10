//
//  FoundationModelsService.swift
//  MedJourney
//
//  Core/AI — On-device AI layer using Apple Foundation Models (iOS 26+)
//
//  Architecture: On-Device only — no network calls, zero Gemini tokens used.
//
//  Three responsibilities:
//  1. Pre-process journal text before any cloud call (urgency detection + extraction)
//  2. Generate contextual journal opening prompts from local health data
//  3. Phrase pre-calculated statistics as readable insight sentences
//

import Foundation
import FoundationModels

// MARK: - Data Types

/// Result from on-device journal pre-processing.
///
/// `cleanedContent` is what gets forwarded to Gemini — the raw user text stays on-device.
struct JournalPreProcessingResult {
    let isUrgent: Bool
    /// Red-flag phrases that triggered the urgency flag
    let urgentKeywords: [String]
    /// Specific symptoms / body complaints extracted from the text
    let extractedSymptoms: [String]
    /// Noise-stripped version ready for the cloud prompt
    let cleanedContent: String
}

/// Local health context used to build a personalised journal opening prompt.
/// All fields are optional so callers can pass only what's available.
struct JournalPromptContext {
    var recentTags: [String] = []
    var hadUrgencyFlag: Bool = false
    var yesterdayChecklistCompletion: Double? = nil
    var completedItemLabels: [String] = []
    var skippedItemLabels: [String] = []
    var recentVitalsBP: String? = nil
    var recentVitalsHR: Int? = nil
    var recentVitalsTemp: Double? = nil
    var hasVitalsAnomaly: Bool = false
    var recentMedicationNames: [String] = []
    var daysSinceLastEntry: Int? = nil
}

// MARK: - Service

/// On-device AI service — Apple Foundation Models (iOS 26+).
///
/// Privacy architecture: raw journal text is pre-processed here before any cloud call.
/// Gemini only ever receives cleaned, structured output from this layer.
///
/// On-Device AI layer — free, private, instant. No network required.
final class FoundationModelsService {

    static let shared = FoundationModelsService()

    /// Cached inference result.
    ///
    /// - `nil`   — not yet tested (first call will try)
    /// - `true`  — a successful `respond()` call has been made; model works
    /// - `false` — a `GenerationError -1` (model assets missing) was received;
    ///             all subsequent calls skip immediately to avoid hammering the
    ///             system and producing noisy log spam
    ///
    /// Thread-safety note: reads/writes happen on Swift concurrency tasks. For a
    /// shared singleton this is fine in practice; a proper actor would be overkill here.
    nonisolated(unsafe) private var inferenceConfirmed: Bool? = nil

    private init() {
        let availability = SystemLanguageModel.default.availability
        switch availability {
        case .available:
            print("🧠 [FoundationModels] ✅ Apple Intelligence available — on-device AI ready")
        case .unavailable(let reason):
            print("🧠 [FoundationModels] ⚠️ Apple Intelligence unavailable — reason: \(reason)")
            inferenceConfirmed = false
        @unknown default:
            print("🧠 [FoundationModels] ⚠️ Apple Intelligence availability unknown")
        }
    }

    /// True when Apple Intelligence is available AND the model assets are confirmed
    /// to be downloaded on this device.
    ///
    /// `SystemLanguageModel.default.availability` can return `.available` even when
    /// the underlying model catalog hasn't been downloaded yet (common in the simulator
    /// and on fresh devices). After the first `GenerationError -1`, `isAvailable`
    /// returns `false` for the rest of the session to prevent repeated failures.
    var isAvailable: Bool {
        // If a previous call confirmed unavailability, skip immediately
        if inferenceConfirmed == false { return false }
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    // MARK: - Error Handling

    /// Called in every `catch` block. If the error is a `GenerationError` with
    /// code -1 (model catalog assets missing), caches the unavailability so future
    /// calls skip without retrying.
    private func handleInferenceError(_ error: Error) {
        let nsError = error as NSError
        // Domain produced by the FoundationModels framework for missing asset errors:
        //   "FoundationModels.LanguageModelSession.GenerationError error -1."
        // Code -1 specifically means model catalog assets are not downloaded.
        // Positive codes (guardrails, unsupported language) are per-request and
        // should NOT mark the model as permanently unavailable.
        if nsError.domain.contains("GenerationError") && nsError.code == -1 {
            inferenceConfirmed = false
            print("🧠 [FoundationModels] ⚠️ Model catalog assets not downloaded on this device.")
            print("🧠 [FoundationModels] ⚠️ Marking as unavailable — future calls will skip inference silently.")
            print("🧠 [FoundationModels] ℹ️ To use on-device AI: run on a real iPhone with Apple Intelligence enabled in Settings.")
        }
    }

    // MARK: - 1. Journal Pre-Processing

    /// Analyzes journal text on-device BEFORE anything is sent to Gemini.
    ///
    /// - Detects urgent / red-flag medical language and returns `isUrgent: true`
    /// - Extracts symptom keywords for local tag augmentation
    /// - Strips noise so only medically relevant content reaches the cloud
    ///
    /// Privacy: raw text is processed entirely on-device; only `cleanedContent`
    /// is ever forwarded to Gemini.
    func preProcessJournalEntry(_ text: String) async -> JournalPreProcessingResult {
        print("🧠 [FoundationModels] preProcessJournalEntry called — text length: \(text.count)")

        let fallback = JournalPreProcessingResult(
            isUrgent: false, urgentKeywords: [], extractedSymptoms: [], cleanedContent: text
        )

        guard isAvailable else {
            print("🧠 [FoundationModels] ⚠️ Apple Intelligence unavailable — returning fallback (no pre-processing)")
            return fallback
        }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("🧠 [FoundationModels] ⏭️ Empty text — skipping pre-processing")
            return fallback
        }

        let session = LanguageModelSession()
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

        print("🧠 [FoundationModels] Sending prompt to on-device model (prompt length: \(prompt.count))...")
        let startTime = Date()

        do {
            let response = try await session.respond(to: prompt)
            inferenceConfirmed = true
            let elapsed = String(format: "%.2f", Date().timeIntervalSince(startTime))
            print("🧠 [FoundationModels] ✅ Response received in \(elapsed)s — content length: \(response.content.count)")

            let result = parsePreProcessingResult(from: response.content, originalText: text)
            print("🧠 [FoundationModels] Parsed: isUrgent=\(result.isUrgent), urgentKeywords=\(result.urgentKeywords), symptoms=\(result.extractedSymptoms.count) found, cleanedLength=\(result.cleanedContent.count)")
            return result
        } catch {
            handleInferenceError(error)
            print("🧠 [FoundationModels] ❌ Pre-processing failed: \(error.localizedDescription)")
            return fallback
        }
    }

    private func parsePreProcessingResult(from raw: String, originalText: String) -> JournalPreProcessingResult {
        let stripped = raw
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard
            let data = stripped.data(using: .utf8),
            let obj  = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
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

    // MARK: - 2. Journal Opening Prompt

    /// Generates a warm, contextual opening question shown above the journal text field.
    ///
    /// Built entirely from local data — zero Gemini tokens consumed.
    /// Returns nil if Foundation Models is unavailable or context is empty.
    func generateJournalOpeningPrompt(context: JournalPromptContext) async -> String? {
        print("🧠 [FoundationModels] generateJournalOpeningPrompt called")

        guard isAvailable else {
            print("🧠 [FoundationModels] ⚠️ Apple Intelligence unavailable — no prompt generated")
            return nil
        }

        var lines: [String] = []

        if let days = context.daysSinceLastEntry {
            lines.append(days == 0
                ? "User journaled earlier today."
                : "Last journal entry was \(days) day\(days == 1 ? "" : "s") ago.")
        }
        if !context.recentTags.isEmpty {
            lines.append("Recent health patterns: \(context.recentTags.prefix(5).joined(separator: ", ")).")
        }
        if context.hadUrgencyFlag {
            lines.append("Their last entry had a health concern flagged.")
        }
        if let pct = context.yesterdayChecklistCompletion {
            let p = Int(pct * 100)
            let done = context.completedItemLabels.prefix(2).joined(separator: " and ")
            lines.append("Yesterday's health checklist was \(p)% completed\(done.isEmpty ? "" : ", including \(done)").")
        }
        if let bp = context.recentVitalsBP {
            lines.append("Most recent blood pressure reading: \(bp).")
            if context.hasVitalsAnomaly {
                lines.append("One or more vitals recently looked different from their usual personal range.")
            }
        }
        if !context.recentMedicationNames.isEmpty {
            lines.append("New medications started recently: \(context.recentMedicationNames.joined(separator: ", ")).")
        }

        guard !lines.isEmpty else {
            print("🧠 [FoundationModels] ⏭️ No context available — using default placeholder")
            return nil
        }

        print("🧠 [FoundationModels] Built \(lines.count) context lines for prompt generation")

        let session = LanguageModelSession()
        let prompt = """
        You are MedCare AI, a warm health companion. Write ONE short, friendly question (max 2 sentences) to open the user's journal session.

        Rules:
        - Conversational and caring, never clinical or formal
        - Reference something specific from the context (habits, streak, sleep patterns), but do NOT quote numbers directly
        - Do NOT name, suggest, or imply any medical condition or diagnosis
        - Max 2 sentences total — no bullet points, no lists
        - Sound like a caring friend checking in, not a doctor or medical professional

        User's recent health context:
        \(lines.joined(separator: "\n"))

        Write only the question, nothing else.
        """

        print("🧠 [FoundationModels] Generating opening prompt (prompt length: \(prompt.count))...")
        let startTime = Date()

        do {
            let response = try await session.respond(to: prompt)
            inferenceConfirmed = true
            let elapsed = String(format: "%.2f", Date().timeIntervalSince(startTime))
            let result = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            print("🧠 [FoundationModels] ✅ Prompt generated in \(elapsed)s — \"\(result.prefix(80))\(result.count > 80 ? "..." : "")\"")
            return result.isEmpty ? nil : result
        } catch {
            handleInferenceError(error)
            print("🧠 [FoundationModels] ❌ Opening prompt generation failed: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - 3. Live Journal Tag Extraction

    /// Extracts 2–5 health-related tags from partially-typed journal text.
    ///
    /// Designed for real-time use — called on debounced text changes, not on every keystroke.
    /// Returns `nil` if the text is < 20 characters or the model is unavailable.
    func extractLiveTags(from text: String) async -> [String]? {
        guard isAvailable else { return nil }
        guard text.trimmingCharacters(in: .whitespacesAndNewlines).count >= 20 else { return nil }

        let session = LanguageModelSession()
        let prompt = """
        Extract 2–5 short health tag labels from this journal text.

        Rules:
        - Each tag is 1–3 words max (e.g. "headache", "low energy", "poor sleep")
        - Only include tags clearly supported by the text — no guessing
        - Return ONLY a JSON array of lowercase strings, nothing else
        - Example: ["headache", "fatigue", "nausea"]
        - If no clear health topics yet, return: []

        Text: \(text.prefix(300))
        """

        print("🧠 [FoundationModels] extractLiveTags called — text length: \(text.count)")

        do {
            let response = try await session.respond(to: prompt)
            inferenceConfirmed = true
            let raw = response.content
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let data = raw.data(using: .utf8),
               let tags = try? JSONSerialization.jsonObject(with: data) as? [String] {
                print("🧠 [FoundationModels] ✅ Live tags extracted: \(tags)")
                return tags.isEmpty ? nil : Array(tags.prefix(5))
            }
            return nil
        } catch {
            handleInferenceError(error)
            print("🧠 [FoundationModels] ❌ Live tag extraction failed: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - 4. Home Screen Welcome Insight

    /// Generates a single warm welcome sentence for the home screen based on recent health context.
    ///
    /// Called once when HomeTabView appears. Returns nil if model unavailable or context is empty.
    func generateWelcomeInsight(
        recentTags: [String],
        anomalyMessages: [String],
        yesterdayCompletion: Double?,
        daysSinceLastEntry: Int?,
        healthContext: String? = nil
    ) async -> String? {
        guard isAvailable else { return nil }

        var lines: [String] = []

        // Curated MD context first — this is the user's documented history (conditions,
        // lab trends, recent flags). Including it makes the greeting specific, not generic.
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

        let session = LanguageModelSession()
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

        print("🧠 [FoundationModels] generateWelcomeInsight called")

        do {
            let response = try await session.respond(to: prompt)
            inferenceConfirmed = true
            let result = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            print("🧠 [FoundationModels] ✅ Welcome insight: \"\(result)\"")
            return result.isEmpty ? nil : result
        } catch {
            handleInferenceError(error)
            print("🧠 [FoundationModels] ❌ Welcome insight failed: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - 5. Insight Phrasing

    /// Turns pre-calculated tag frequency counts into a readable 1–2 sentence insight.
    ///
    /// Input is Swift-calculated numbers only — no raw journal entries involved.
    func phraseTagInsight(tagCounts: [String: Int], periodLabel: String) async -> String? {
        print("🧠 [FoundationModels] phraseTagInsight called — \(tagCounts.count) tag types for \(periodLabel)")

        guard isAvailable else {
            print("🧠 [FoundationModels] ⚠️ Apple Intelligence unavailable — no insight generated")
            return nil
        }
        guard !tagCounts.isEmpty else {
            print("🧠 [FoundationModels] ⏭️ No tag data — skipping insight")
            return nil
        }

        let top = tagCounts
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { "\($0.key) (\($0.value) times)" }
            .joined(separator: ", ")

        let session = LanguageModelSession()
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

        print("🧠 [FoundationModels] Phrasing insight (prompt length: \(prompt.count))...")
        let startTime = Date()

        do {
            let response = try await session.respond(to: prompt)
            inferenceConfirmed = true
            let elapsed = String(format: "%.2f", Date().timeIntervalSince(startTime))
            let result = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            print("🧠 [FoundationModels] ✅ Insight phrased in \(elapsed)s — \"\(result.prefix(80))\(result.count > 80 ? "..." : "")\"")
            return result.isEmpty ? nil : result
        } catch {
            handleInferenceError(error)
            print("🧠 [FoundationModels] ❌ Insight phrasing failed: \(error.localizedDescription)")
            return nil
        }
    }
}
