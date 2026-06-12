//
//  ChecklistGenerationService.swift
//  MedJourney
//

import Foundation

/// One suggested daily habit, as returned by the LLM.
struct ChecklistGenerationItem: Codable {
    let emoji: String
    let text: String
}

/// Generates the daily wellness checklist from checkup results, plus a cloud
/// fallback for phrasing tag statistics when Apple Intelligence is unavailable.
final class ChecklistGenerationService {

    init() {}

    /// Suggests up to 5 supportive daily habits from a checkup's OCR text and doctor notes.
    func generateChecklist(ocrText: String, notes: String) async throws -> [ChecklistGenerationItem] {
        let prompt = """
        You are MedCare AI, a warm health companion. Based on this medical checkup result and doctor notes, suggest up to 5 supportive daily health habits for this patient.

        Return ONLY a valid JSON array (no extra text, no markdown):
        [
          {"emoji": "🏃", "text": "15 min morning walk"},
          {"emoji": "💧", "text": "Drink 2.5L water daily"}
        ]

        SAFETY RULES:
        - Do NOT diagnose any condition or name any illness. Focus on supportive daily habits only.
        - Do NOT suggest any specific medication, dosage, or medical treatment.
        - Suggestions should be general wellness habits a person can safely start without medical supervision.
        - If doctor notes mention specific instructions, reflect those in the habit (e.g. "Take medication at 8am") without clinical interpretation.

        Rules:
        - Maximum 5 items, minimum 1
        - Short, friendly, actionable phrases (max 7 words each)
        - Use warm, encouraging emojis
        - Focus on the most supportive daily habits given the results
        - Mix movement, hydration, nutrition, sleep, and stress habits

        Medical checkup data:
        \(ocrText.isEmpty ? "(no OCR text provided)" : ocrText)

        Doctor notes / additional context:
        \(notes.isEmpty ? "(none)" : notes)
        """

        let response = try await LLMGateway.shared.complete(prompt: prompt, jsonMode: true)

        guard let data = response.data(using: .utf8),
              let items = try? JSONDecoder().decode([ChecklistGenerationItem].self, from: data) else {
            return []
        }
        return Array(items.prefix(5))
    }

    /// Cloud fallback for phrasing tag-frequency stats — used only when
    /// `FoundationModelsService` is unavailable on the device.
    func phraseTagInsight(tagCounts: [String: Int], periodLabel: String) async throws -> String {
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
        - Describe patterns and frequencies only — do NOT name or suggest any medical condition or diagnosis
        - Use observational language: "you've mentioned headaches frequently" not "you may have migraines"
        - No medical jargon, no bullet points
        - Max 2 sentences total

        Write only the insight sentences, nothing else.
        """

        let result = try await LLMGateway.shared.complete(prompt: prompt, jsonMode: false)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
