import Foundation

struct ChecklistGenerationItem: Codable {
    let emoji: String
    let text: String
}

final class ChecklistGenerationService {
    private let apiKey: String

    init(apiKey: String) {
        self.apiKey = apiKey
    }

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

        let responseText = try await callGemini(prompt: prompt, jsonMode: true)

        guard
            let arrayData = responseText.data(using: .utf8),
            let items = try? JSONDecoder().decode([ChecklistGenerationItem].self, from: arrayData)
        else {
            return []
        }

        return Array(items.prefix(5))
    }

    // NOTE: generateHealthSummaryFromStats(_:) — the Insights "Deep AI Summary"
    // call that bundled fresh local stats into a Gemini prompt — has been removed.
    // That responsibility is now powered by the curated `health_summary.md`
    // knowledge base via `LLMAnalysisService.generateHealthInsights`, wired up
    // from `InsightsViewModel.generateDeepSummary()`. See README_AI_PIPELINE.md.

    // MARK: - On-Device Fallbacks (called when Foundation Models is unavailable)
    //
    // NOTE: generateWelcomeMessage(...) — the Home daily-briefing fallback that
    // bundled fresh local context (recent tags, anomalies, checklist rate, days
    // since last entry) into a Gemini prompt — has been removed. That
    // responsibility is now powered by the curated `health_summary.md` "Daily
    // Summary Context" slice via `DailySummaryService.generateGreeting()`,
    // wired up from `HomeViewModel.loadWelcomeInsight`. See README_AI_PIPELINE.md.

    /// Gemini fallback for phrasing tag frequency insight.
    ///
    /// Called only when Apple Intelligence is not available on the device.
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
        let result = try await callGemini(prompt: prompt, jsonMode: false)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Private

    private func callGemini(prompt: String, jsonMode: Bool) async throws -> String {
        guard !apiKey.isEmpty, apiKey != "YOUR_GEMINI_API_KEY_HERE" else {
            print("📋 [ChecklistGenerationService] ❌ API key is missing — Gemini call skipped. Add key to Config.plist or GEMINI_API_KEY env var.")
            throw AITagError.missingAPIKey
        }
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-goog-api-key")

        var body: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]]
        ]
        if jsonMode {
            body["generationConfig"] = ["responseMimeType": "application/json"]
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AITagError.apiError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let candidates = json["candidates"] as? [[String: Any]],
            let content = candidates.first?["content"] as? [String: Any],
            let parts = content["parts"] as? [[String: Any]],
            let text = parts.first?["text"] as? String
        else {
            throw AITagError.parseError
        }

        return text
    }
}
