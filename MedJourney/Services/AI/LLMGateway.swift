//
//  LLMGateway.swift
//  MedJourney
//
//  Services/AI — THE single gate for every cloud LLM call in the app.
//
//  ┌──────────────────────────────────────────────────────────────────────────┐
//  │  ONE-WAY GATE                                                              │
//  │                                                                            │
//  │  Every feature that needs a cloud LLM — journal tagging, checkup analysis, │
//  │  checklist generation, daily greeting, deep insights — calls:             │
//  │                                                                            │
//  │      LLMGateway.shared.complete(prompt:jsonMode:)                          │
//  │                                                                            │
//  │  No feature talks to Gemini / Groq / OpenAI directly. To switch provider,  │
//  │  model, or fallback order, edit ONLY this file (`providerChain` + the      │
//  │  `call<Provider>` methods). Nothing else in the app changes.               │
//  └──────────────────────────────────────────────────────────────────────────┘
//

import Foundation

/// Canonical error type thrown by every LLM call. (Shared with `LLMAnalysisError`
/// which mirrors these cases for back-compat in the Insights deep-summary flow.)
enum LLMGatewayError: LocalizedError {
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

/// Supported cloud LLM providers.
///
/// To add a new provider: add a case here, add its key accessor to `AIConfig`,
/// implement a `call<Provider>` method below, handle the case in `complete`,
/// and insert it into `providerChain`.
enum LLMProvider: String {
    case groq   = "Groq (llama-3.3-70b)"
    case gemini = "Gemini 2.0 Flash"
    // case openAI    = "OpenAI GPT-4o"   ← add a callOpenAI + AIConfig.openAIKey
    // case anthropic = "Claude Haiku"    ← add a callAnthropic + AIConfig.anthropicKey
}

/// The single transport every LLM call funnels through.
final class LLMGateway {

    static let shared = LLMGateway()

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Ordered provider preference. The first provider with a configured key is used;
    /// if it returns 429 (quota/rate limit) the gate falls through to the next one.
    /// **Change provider priority here.**
    private var providerChain: [LLMProvider] { [.groq, .gemini] }

    // MARK: - The Gate

    /// The one entry point for all cloud LLM calls. Prompt in → text out.
    ///
    /// - Parameters:
    ///   - prompt: The fully-built prompt.
    ///   - jsonMode: When true, asks the provider to return strict JSON.
    /// - Returns: The model's raw text response.
    func complete(prompt: String, jsonMode: Bool) async throws -> String {
        guard !prompt.isEmpty else { return "" }

        var lastError: Error = LLMGatewayError.missingAPIKey

        for provider in providerChain {
            do {
                switch provider {
                case .groq:
                    let key = AIConfig.groqKey
                    guard isUsable(key, placeholder: "YOUR_GROQ_API_KEY_HERE") else {
                        print("🛂 [LLMGateway] ⏭️ Skipping Groq — no key in Config.plist")
                        continue
                    }
                    return try await callGroq(prompt: prompt, jsonMode: jsonMode, apiKey: key)

                case .gemini:
                    let key = AIConfig.llmAPIKey
                    guard isUsable(key, placeholder: "YOUR_GEMINI_API_KEY_HERE") else {
                        print("🛂 [LLMGateway] ⏭️ Skipping Gemini — no key in Config.plist")
                        continue
                    }
                    return try await callGemini(prompt: prompt, jsonMode: jsonMode, apiKey: key)
                }
            } catch LLMGatewayError.missingAPIKey {
                continue   // no key → try next provider
            } catch LLMGatewayError.apiError(let code) where code == 429 {
                lastError = LLMGatewayError.apiError(code)
                print("🛂 [LLMGateway] ⏭️ \(provider.rawValue) rate-limited (429) — trying next provider")
                continue   // quota exhausted → fall through to next provider
            } catch {
                throw error   // real error (bad request, parse fail, etc.) — don't swallow
            }
        }

        // All providers failed or were unconfigured.
        throw lastError
    }

    private func isUsable(_ key: String, placeholder: String) -> Bool {
        !key.isEmpty && key != placeholder
    }

    // MARK: - Provider implementations

    /// Groq API (OpenAI-compatible). Free tier: 14,400 RPD / 6,000 RPM.
    /// Model: llama-3.3-70b-versatile
    private func callGroq(prompt: String, jsonMode: Bool, apiKey: String, retries: Int = 1) async throws -> String {
        print("🛂 [LLMGateway] → Groq. jsonMode=\(jsonMode), key=\(apiKey.prefix(8))…, promptLen=\(prompt.count)")

        let url = URL(string: "https://api.groq.com/openai/v1/chat/completions")!
        var request = URLRequest(url: url)
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
        print("🛂 [LLMGateway] Groq status: \(statusCode)")

        if statusCode == 429, retries > 0 {
            let body = String(data: data, encoding: .utf8) ?? ""
            print("🛂 [LLMGateway] ⏳ Groq 429 — waiting 5s, retrying (\(retries) left). \(body.prefix(120))")
            try await Task.sleep(nanoseconds: 5_000_000_000)
            return try await callGroq(prompt: prompt, jsonMode: jsonMode, apiKey: apiKey, retries: retries - 1)
        }

        guard statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "(unreadable)"
            print("🛂 [LLMGateway] ❌ Groq HTTP \(statusCode): \(body.prefix(300))")
            throw LLMGatewayError.apiError(statusCode)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let text = message["content"] as? String else {
            let raw = String(data: data, encoding: .utf8) ?? "(unreadable)"
            print("🛂 [LLMGateway] ❌ Groq parseError: \(raw.prefix(300))")
            throw LLMGatewayError.parseError
        }

        print("🛂 [LLMGateway] ✅ Groq OK, textLen=\(text.count)")
        return text
    }

    /// Gemini 2.0 Flash. Free tier: 200 RPD / 15 RPM.
    private func callGemini(prompt: String, jsonMode: Bool, apiKey: String, retries: Int = 1) async throws -> String {
        print("🛂 [LLMGateway] → Gemini. jsonMode=\(jsonMode), key=\(apiKey.prefix(8))…, promptLen=\(prompt.count)")

        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-goog-api-key")

        var body: [String: Any] = ["contents": [["parts": [["text": prompt]]]]]
        if jsonMode { body["generationConfig"] = ["responseMimeType": "application/json"] }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        print("🛂 [LLMGateway] Gemini status: \(statusCode)")

        if statusCode == 429, retries > 0 {
            let body = String(data: data, encoding: .utf8) ?? ""
            print("🛂 [LLMGateway] ⏳ Gemini 429 — waiting 6s, retrying (\(retries) left). \(body.prefix(120))")
            try await Task.sleep(nanoseconds: 6_000_000_000)
            return try await callGemini(prompt: prompt, jsonMode: jsonMode, apiKey: apiKey, retries: retries - 1)
        }

        guard statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "(unreadable)"
            print("🛂 [LLMGateway] ❌ Gemini HTTP \(statusCode): \(body.prefix(300))")
            throw LLMGatewayError.apiError(statusCode)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let content = candidates.first?["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String else {
            let raw = String(data: data, encoding: .utf8) ?? "(unreadable)"
            print("🛂 [LLMGateway] ❌ Gemini parseError: \(raw.prefix(300))")
            throw LLMGatewayError.parseError
        }

        print("🛂 [LLMGateway] ✅ Gemini OK, textLen=\(text.count)")
        return text
    }
}

// MARK: - Error bridging

extension LLMGatewayError {
    /// Maps a gateway error to the legacy `AITagError` used by the tag/checklist services.
    var asAITagError: AITagError {
        switch self {
        case .missingAPIKey:      return .missingAPIKey
        case .apiError(let code): return .apiError(code)
        case .parseError:         return .parseError
        }
    }

    /// Maps a gateway error to the legacy `LLMAnalysisError` used by the Insights flow.
    var asLLMAnalysisError: LLMAnalysisError {
        switch self {
        case .missingAPIKey:      return .missingAPIKey
        case .apiError(let code): return .apiError(code)
        case .parseError:         return .parseError
        }
    }
}
