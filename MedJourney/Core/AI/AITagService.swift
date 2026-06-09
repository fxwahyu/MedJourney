//
//  AITagService.swift
//  MedJourney
//
//  Core/AI — Generates smart health tags from journal entry data using Claude
//

import Foundation

// MARK: - Models

/// The result from the AI analysis containing tags and detailed markdown analysis
struct AITagResult {
    let tags: [String]
    let analysis: String?
}

// MARK: - Protocol

/// Generates AI-powered health tags from a journal entry's content.
protocol AITagServiceProtocol {
    func generateTags(for entry: JournalEntry, ocrText: String?) async throws -> AITagResult
}

// MARK: - Implementation

/// Calls Claude claude-haiku-4-5 to extract meaningful health tags from a journal entry.
///
/// Tags are used in `JournalCardView` to give a quick health snapshot.
/// Tag types generated:
/// - **Mood**: e.g. "Sick day", "Feeling low"
/// - **Symptoms**: extracted from description, e.g. "Headache", "Ibuprofen"
/// - **Abnormal vitals**: e.g. "High BP", "Fever"
/// - **Checkup analysis**: for Medical Analysis entry type
final class AITagService: AITagServiceProtocol {

    // MARK: - Configuration

    /// Set your Anthropic API key here or inject via environment
    private let apiKey: String
    private let session: URLSession

    init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    // MARK: - Public

    func generateTags(for entry: JournalEntry, ocrText: String? = nil) async throws -> AITagResult {
        let prompt = buildPrompt(for: entry, ocrText: ocrText)
        let raw = try await callClaude(prompt: prompt)
        return AITagResult(tags: parseTags(from: raw), analysis: nil)
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
            lines.append("You are a medical AI assistant. Analyze this checkup entry and generate short diagnostic insight tags.")
            lines.append("Return ONLY a comma-separated list of 2-5 concise tags (3 words max). No explanation, no markdown.")
            lines.append("")
            lines.append("Entry data:")
            if !entry.title.isEmpty { lines.append("Title: \(entry.title)") }
            if !entry.content.isEmpty { lines.append("Notes: \(entry.content)") }
            if let bp = entry.bloodPressure { lines.append("Blood pressure: \(bp) mmHg") }
            if let hr = entry.heartRate { lines.append("Heart rate: \(hr) bpm") }
            if let temp = entry.temperature { lines.append("Temperature: \(temp)°C") }

        case .medication:
            // Not implemented per spec
            return ""
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Claude API Call

    private func callClaude(prompt: String) async throws -> String {
        guard !prompt.isEmpty else { return "" }
        print("🤖 [AITagService] Starting Claude generation. Prompt length: \(prompt.count)")

        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": "claude-3-haiku-20240307",
            "max_tokens": 100,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        print("🤖 [AITagService] Sending request to Anthropic API...")

        let (data, response) = try await session.data(for: request)
        
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        print("🤖 [AITagService] Received response. Status code: \(statusCode)")

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            if let errorString = String(data: data, encoding: .utf8) {
                print("🤖 [AITagService] ❌ API Error: \(errorString)")
            }
            throw AITagError.apiError(statusCode)
        }

        print("🤖 [AITagService] Raw JSON response: \(String(data: data, encoding: .utf8) ?? "unable to decode")")

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let text = content.first?["text"] as? String else {
            print("🤖 [AITagService] ❌ Failed to parse expected JSON structure.")
            throw AITagError.parseError
        }

        print("🤖 [AITagService] ✅ Successfully parsed tags: \(text)")
        return text
    }

    // MARK: - Tag Parsing

    private func parseTags(from raw: String) -> [String] {
        raw.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "\"'")) }
            .filter { !$0.isEmpty }
            .prefix(6)
            .map { String($0) }
    }
}

// MARK: - Errors

enum AITagError: LocalizedError {
    case missingAPIKey
    case apiError(Int)
    case parseError

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:      return "No API key configured (Config.plist / environment variable)."
        case .apiError(let code): return "AI tag service error: HTTP \(code)"
        case .parseError:         return "Failed to parse AI service response"
        }
    }
}
