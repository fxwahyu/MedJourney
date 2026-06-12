//
//  LLMGateway.swift
//  MedJourney
//

import Foundation

/// Error thrown by any cloud LLM call in the app.
enum LLMError: LocalizedError {
    case missingAPIKey
    case apiError(Int)
    case parseError

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:      return "No LLM API key configured (Config.plist / environment)."
        case .apiError(let code): return "LLM API error: HTTP \(code)"
        case .parseError:         return "Failed to parse LLM response."
        }
    }
}

/// The single transport for every cloud LLM call in the app.
///
/// Features never talk to a provider directly — they call `complete(prompt:jsonMode:)`
/// and the gateway picks the first configured provider, falling through to the next
/// one on rate limits (HTTP 429). To change provider, model, or fallback order,
/// edit only this file.
final class LLMGateway {

    static let shared = LLMGateway()

    private enum Provider: CaseIterable {
        case groq
        case gemini
    }

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Public

    /// Sends a prompt to the first available provider and returns the raw text response.
    /// - Parameter jsonMode: When true, asks the provider for strict JSON output.
    func complete(prompt: String, jsonMode: Bool) async throws -> String {
        guard !prompt.isEmpty else { return "" }

        var lastError: Error = LLMError.missingAPIKey

        for provider in Provider.allCases {
            do {
                switch provider {
                case .groq:
                    guard isUsable(AIConfig.groqKey) else { continue }
                    return try await callGroq(prompt: prompt, jsonMode: jsonMode, apiKey: AIConfig.groqKey)
                case .gemini:
                    guard isUsable(AIConfig.geminiKey) else { continue }
                    return try await callGemini(prompt: prompt, jsonMode: jsonMode, apiKey: AIConfig.geminiKey)
                }
            } catch LLMError.missingAPIKey {
                continue
            } catch LLMError.apiError(429) {
                // Quota exhausted on this provider — fall through to the next one.
                lastError = LLMError.apiError(429)
                continue
            }
        }

        throw lastError
    }

    // MARK: - Providers

    private func isUsable(_ key: String) -> Bool {
        !key.isEmpty && !key.hasPrefix("YOUR_")
    }

    private func callGroq(prompt: String, jsonMode: Bool, apiKey: String, retries: Int = 1) async throws -> String {
        var request = URLRequest(url: URL(string: "https://api.groq.com/openai/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        var body: [String: Any] = [
            "model": "llama-3.3-70b-versatile",
            "messages": [["role": "user", "content": prompt]],
            "temperature": 0.3
        ]
        if jsonMode { body["response_format"] = ["type": "json_object"] }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

        if statusCode == 429, retries > 0 {
            try await Task.sleep(for: .seconds(5))
            return try await callGroq(prompt: prompt, jsonMode: jsonMode, apiKey: apiKey, retries: retries - 1)
        }
        guard statusCode == 200 else { throw LLMError.apiError(statusCode) }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let text = message["content"] as? String else {
            throw LLMError.parseError
        }
        return text
    }

    private func callGemini(prompt: String, jsonMode: Bool, apiKey: String, retries: Int = 1) async throws -> String {
        var request = URLRequest(url: URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-goog-api-key")

        var body: [String: Any] = ["contents": [["parts": [["text": prompt]]]]]
        if jsonMode { body["generationConfig"] = ["responseMimeType": "application/json"] }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

        if statusCode == 429, retries > 0 {
            try await Task.sleep(for: .seconds(6))
            return try await callGemini(prompt: prompt, jsonMode: jsonMode, apiKey: apiKey, retries: retries - 1)
        }
        guard statusCode == 200 else { throw LLMError.apiError(statusCode) }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let content = candidates.first?["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String else {
            throw LLMError.parseError
        }
        return text
    }
}
