//
//  GeminiTagService.swift
//  MedJourney
//
//  Core/AI — Generates smart health tags using Google's Gemini API
//

import Foundation

/// Calls Google's Gemini API (Gemini 1.5 Flash) to extract meaningful health tags and analysis from a journal entry.
final class GeminiTagService: AITagServiceProtocol {

    // MARK: - Configuration

    private let apiKey: String
    private let session: URLSession

    init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    // MARK: - Public

    func generateTags(for entry: JournalEntry, ocrText: String? = nil) async throws -> AITagResult {
        let prompt = buildPrompt(for: entry, ocrText: ocrText)
        let raw = try await callGemini(prompt: prompt, isCheckup: entry.entryType == .checkup)

        if entry.entryType == .checkup {
            return parseJSON(from: raw)
        } else {
            return AITagResult(tags: parseTags(from: raw), analysis: nil)
        }
    }

    // MARK: - Prompt Building

    private func buildPrompt(for entry: JournalEntry, ocrText: String?) -> String {
        var lines: [String] = []

        switch entry.entryType {

        case .journal:
            lines.append("You are a health data assistant. Extract concise observational tags from this journal entry.")
            lines.append("Return ONLY a comma-separated list of 2-6 short tags (2-3 words max each). No explanation.")
            lines.append("")
            lines.append("SAFETY RULES — follow these exactly:")
            lines.append("- Do NOT name or suggest any specific medical conditions, diseases, or diagnoses.")
            lines.append("- Use observational, symptom-based language only (e.g. 'headache' not 'migraine', 'elevated BP' not 'hypertension').")
            lines.append("- If vitals are outside normal range, describe the observation — never infer a diagnosis from it.")
            lines.append("")
            lines.append("Rules:")
            lines.append("- First tag: mood level (e.g. 'Sick day', 'Low energy', 'Feeling great')")
            lines.append("- Next tags: specific symptoms or observations from the description")
            lines.append("- Last tags: flag any abnormal vitals (skip normal values)")
            lines.append("  - High BP: systolic >140 or diastolic >90 → tag as 'elevated BP'")
            lines.append("  - Low BP: systolic <90 → tag as 'low BP reading'")
            lines.append("  - High HR: >100 bpm → tag as 'elevated heart rate'")
            lines.append("  - Fever: >37.5°C → tag as 'fever'")
            lines.append("  - Low temp: <36°C → tag as 'low temperature'")
            lines.append("- Never use diagnostic labels as tags")
            lines.append("")
            lines.append("Entry data:")
            lines.append("Mood: \(entry.title)")
            if !entry.content.isEmpty {
                lines.append("Description: \(entry.content)")
            }
            if let bp = entry.bloodPressure { lines.append("Blood pressure: \(bp) mmHg") }
            if let hr = entry.heartRate     { lines.append("Heart rate: \(hr) bpm") }
            if let temp = entry.temperature { lines.append("Temperature: \(temp)°C") }

        case .checkup:
            lines.append("""
            You are MedCare AI, a health companion helping a patient understand their checkup results in plain, caring language.
            Analyze the entry below and return a valid JSON object with this exact schema:

            {
              "tags": ["string", "string"],
              "sections": [
                {
                  "heading": "Section Title",
                  "items": ["string", "string"]
                }
              ]
            }

            SAFETY RULES — follow these exactly, no exceptions:
            - Do NOT name, diagnose, or suggest any specific medical condition, disease, or illness.
            - Do NOT say "you have [condition]", "this indicates [disease]", or "this is [diagnosis]".
            - Use observational language only: describe what the numbers show, not what they mean diagnostically.
              For example: "Your hemoglobin reading was below the normal reference range." NOT "You have anemia."
              For example: "Your fasting glucose was slightly above the standard reference." NOT "You may have diabetes."
            - Any abnormal result should be framed as: "worth discussing with your doctor", never as a diagnosis.
            - Always end recommendations by encouraging the patient to consult their healthcare provider.

            CRITICAL FORMATTING RULES:
            - "tags": 3 to 6 short observational tags describing what was found (e.g. "Hemoglobin below range", "Normal glucose", "BP above reference").
              Tags must be observational — never diagnostic labels.
            - "sections": each section has "heading" (plain text) and "items" (array of strings, one sentence each).
            - Do NOT use markdown symbols like ###, **, *, or - inside any string value.
            - Every "items" entry must end with a period.

            Use EXACTLY these section headings in this order:
            1. "Overview" — 2 to 3 warm sentences summarizing the overall results in simple, non-diagnostic terms.
            2. "What Your Results Show" — explain each reading: what it measures, whether it is within or outside the normal reference range.
            3. "Good Questions for Your Doctor" — specific questions worth raising at your next appointment, based on these results.
            4. "Things That May Help" — general lifestyle, nutrition, or daily habit suggestions (not medical treatment).
            5. "Daily Care Ideas" — supportive self-care steps the patient can discuss with their doctor.
            6. "Symptoms to Watch For" — specific new symptoms that should prompt the patient to contact their healthcare provider promptly.
            """)

            lines.append("")
            lines.append("Patient entry data:")
            if !entry.title.isEmpty   { lines.append("Title: \(entry.title)") }
            if !entry.content.isEmpty { lines.append("Notes: \(entry.content)") }
            if let bp   = entry.bloodPressure { lines.append("Blood pressure: \(bp) mmHg") }
            if let hr   = entry.heartRate     { lines.append("Heart rate: \(hr) bpm") }
            if let temp = entry.temperature   { lines.append("Temperature: \(temp)°C") }
            if let ocrText, !ocrText.isEmpty  {
                lines.append("")
                lines.append("Scanned document text:")
                lines.append(ocrText)
            }

        case .medication:
            return ""
        }
        
        return lines.joined(separator: "\n")
    }

    // MARK: - Gemini API Call

    private func callGemini(prompt: String, isCheckup: Bool) async throws -> String {
        guard !prompt.isEmpty else { return "" }
        guard !apiKey.isEmpty, apiKey != "YOUR_GEMINI_API_KEY_HERE" else {
            print("✨ [GeminiTagService] ❌ API key is missing — Gemini call skipped. Add key to Config.plist or GEMINI_API_KEY env var.")
            throw AITagError.missingAPIKey
        }
        print("✨ [GeminiTagService] Starting Gemini generation. Prompt length: \(prompt.count)")

        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent")!
        var request = URLRequest(url: url)
        request.httpMethod  = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-goog-api-key")

        var body: [String: Any] = [
            "contents": [
                ["parts": [["text": prompt]]]
            ]
        ]

        if isCheckup {
            body["generationConfig"] = ["responseMimeType": "application/json"]
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        print("✨ [GeminiTagService] Sending request to Gemini API...")

        let (data, response) = try await session.data(for: request)

        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        print("✨ [GeminiTagService] Received response. Status code: \(statusCode)")

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            if let errorString = String(data: data, encoding: .utf8) {
                print("✨ [GeminiTagService] ❌ API Error: \(errorString)")
            }
            throw AITagError.apiError(statusCode)
        }

        guard
            let json       = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let candidates = json["candidates"] as? [[String: Any]],
            let first      = candidates.first,
            let content    = first["content"] as? [String: Any],
            let parts      = content["parts"] as? [[String: Any]],
            let text       = parts.first?["text"] as? String
        else {
            print("✨ [GeminiTagService] ❌ Failed to parse expected JSON structure.")
            throw AITagError.parseError
        }

        print("✨ [GeminiTagService] ✅ Successfully extracted text. Length: \(text.count)")
        return text
    }

    // MARK: - JSON Parsing

    private func parseJSON(from raw: String) -> AITagResult {
        guard
            let data = raw.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            // Fallback: treat as plain comma-separated tags
            return AITagResult(tags: parseTags(from: raw), analysis: nil)
        }

        // ── Tags ──────────────────────────────────────────────────────────────
        let tags = json["tags"] as? [String] ?? []

        // ── Sections → formatted markdown string ─────────────────────────────
        var markdownParts: [String] = []

        if let sections = json["sections"] as? [[String: Any]] {
            for section in sections {
                guard
                    let heading = section["heading"] as? String,
                    let items   = section["items"]   as? [String]
                else { continue }

                // Section heading
                markdownParts.append("### \(heading)")

                // Each item becomes its own bullet, separated by a blank line for breathing room
                for item in items where !item.trimmingCharacters(in: .whitespaces).isEmpty {
                    markdownParts.append("• \(item.trimmingCharacters(in: .whitespaces))")
                }

                // Blank line between sections
                markdownParts.append("")
            }
        }

        // If the model returned old-style flat "analysis" array as fallback
        if markdownParts.isEmpty {
            if let analysisArray = json["analysis"] as? [String] {
                markdownParts = analysisArray.map { $0.trimmingCharacters(in: .whitespaces) }
            } else if let analysisStr = json["analysis"] as? String {
                markdownParts = [analysisStr]
            }
        }

        let analysisString = markdownParts
            .joined(separator: "\n")   // one newline between every item
            .trimmingCharacters(in: .whitespacesAndNewlines)

        print("✨ [GeminiTagService] Parsed \(tags.count) tags and \(markdownParts.count) lines of analysis.")
        return AITagResult(tags: tags, analysis: analysisString.isEmpty ? nil : analysisString)
    }

    private func parseTags(from raw: String) -> [String] {
        raw.split(separator: ",")
            .map  { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .map  { $0.trimmingCharacters(in: CharacterSet(charactersIn: "\"'")) }
            .filter { !$0.isEmpty }
            .prefix(6)
            .map  { String($0) }
    }
}
