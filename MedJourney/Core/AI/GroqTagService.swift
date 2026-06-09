//
//  GroqTagService.swift
//  MedJourney
//
//  Core/AI — Generates smart health tags using Groq's fast Llama 3 models
//

import Foundation

/// Calls Groq's API (Llama 3 8B) to extract meaningful health tags from a journal entry.
///
/// Groq uses an OpenAI-compatible endpoint structure but runs at ultra-high speeds,
/// making it ideal for real-time tag generation.
final class GroqTagService: AITagServiceProtocol {

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
        let raw = try await callGroq(prompt: prompt)
        return parseJSON(from: raw)
    }

    // MARK: - Prompt Building

    private func buildPrompt(for entry: JournalEntry, ocrText: String?) -> String {
        var lines: [String] = []

        switch entry.entryType {
        case .journal:
            lines.append("You are a health data assistant. Extract concise health tags from this journal entry.")
            lines.append("Return ONLY a comma-separated list of 2-6 short tags (2-3 words max each). No explanation.")
            lines.append("")
            lines.append("Rules:")
            lines.append("- First tag: mood level (e.g. 'Sick day', 'Low energy', 'Feeling great')")
            lines.append("- Next tags: specific symptoms or medications mentioned in the description")
            lines.append("- Last tags: flag any abnormal vitals (skip normal values)")
            lines.append("  - High BP: systolic >140 or diastolic >90")
            lines.append("  - Low BP: systolic <90")
            lines.append("  - High HR: >100 bpm, Low HR: <60 bpm")
            lines.append("  - Fever: >37.5°C, Hypothermia: <36°C")
            lines.append("")
            lines.append("Entry data:")
            lines.append("Mood: \(entry.title)")
            if !entry.content.isEmpty {
                lines.append("Description: \(entry.content)")
            }
            if let bp = entry.bloodPressure { lines.append("Blood pressure: \(bp) mmHg") }
            if let hr = entry.heartRate { lines.append("Heart rate: \(hr) bpm") }
            if let temp = entry.temperature { lines.append("Temperature: \(temp)°C") }

        case .checkup:
            lines.append("You are a medical AI assistant. Analyze this checkup entry and generate diagnostic tags and a detailed, easy-to-understand medical description.")
            lines.append("Output MUST be a valid JSON object matching this schema exactly:")
            lines.append("{")
            lines.append("  \"tags\": [\"string\", \"string\"],")
            lines.append("  \"analysis\": [\"markdown paragraph 1\", \"markdown paragraph 2\", \"- bullet point 1\"]")
            lines.append("}")
            lines.append("")
            lines.append("Rules for analysis:")
            lines.append("- Format with rich Markdown (headings like ###, bold text **).")
            lines.append("- CRITICAL: Break your analysis into an array of strings. Each paragraph, heading, or bullet point MUST be a separate item in the \"analysis\" array.")
            lines.append("- Use bullet points ( - ) heavily to make it easy to read. Each bullet point should be its own string in the array.")
            lines.append("- Explain what each test parameter means.")
            lines.append("- Analyze the current numbers: are they bad/good? What do they indicate?")
            lines.append("- List preventative measures to avoid numbers worsening.")
            lines.append("- List home remedies for the diagnosis.")
            lines.append("")
            lines.append("Entry data:")
            if !entry.title.isEmpty { lines.append("Title: \(entry.title)") }
            if !entry.content.isEmpty { lines.append("Notes: \(entry.content)") }
            if let bp = entry.bloodPressure { lines.append("Blood pressure: \(bp) mmHg") }
            if let hr = entry.heartRate { lines.append("Heart rate: \(hr) bpm") }
            if let temp = entry.temperature { lines.append("Temperature: \(temp)°C") }
            if let ocrText = ocrText, !ocrText.isEmpty {
                lines.append("Scanned Document Text:")
                lines.append(ocrText)
            }

        case .medication:
            return ""
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Groq API Call

    private func callGroq(prompt: String) async throws -> String {
        guard !prompt.isEmpty else { return "" }
        print("⚡️ [GroqTagService] Starting Llama 3 generation. Prompt length: \(prompt.count)")

        let url = URL(string: "https://api.groq.com/openai/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": "llama-3.1-8b-instant", // Groq's fast Llama 3.1 model
            "temperature": 0.5,
            "max_tokens": 1024,
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "response_format": ["type": "json_object"]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        print("⚡️ [GroqTagService] Sending request to Groq API...")

        let (data, response) = try await session.data(for: request)
        
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        print("⚡️ [GroqTagService] Received response. Status code: \(statusCode)")

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            if let errorString = String(data: data, encoding: .utf8) {
                print("⚡️ [GroqTagService] ❌ API Error: \(errorString)")
            }
            throw AITagError.apiError(statusCode)
        }

        print("⚡️ [GroqTagService] Raw JSON response: \(String(data: data, encoding: .utf8) ?? "unable to decode")")

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let text = message["content"] as? String else {
            print("⚡️ [GroqTagService] ❌ Failed to parse expected JSON structure.")
            throw AITagError.parseError
        }

        print("⚡️ [GroqTagService] ✅ Successfully parsed tags: \(text)")
        return text
    }

    // MARK: - JSON Parsing

    private func parseJSON(from raw: String) -> AITagResult {
        guard let data = raw.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return AITagResult(tags: parseTags(from: raw), analysis: nil)
        }
        
        let tags = json["tags"] as? [String] ?? parseTags(from: raw)
        
        var analysisString: String? = nil
        if let analysisArray = json["analysis"] as? [String] {
            analysisString = analysisArray.joined(separator: "\n\n")
        } else if let analysisStr = json["analysis"] as? String {
            analysisString = analysisStr
        }
        
        return AITagResult(tags: tags, analysis: analysisString)
    }

    private func parseTags(from raw: String) -> [String] {
        raw.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "\"'")) }
            .filter { !$0.isEmpty }
            .prefix(6)
            .map { String($0) }
    }
}
