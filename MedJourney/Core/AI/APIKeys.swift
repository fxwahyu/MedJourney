//
//  APIKeys.swift
//  MedJourney
//
//  Configuration — API keys for external services
//
//  ⚠️ Do NOT commit real keys. Use environment variables or a secrets manager in production.
//

import Foundation

enum APIKeys {
    /// Anthropic Claude API key
    /// Set this via Xcode scheme environment variable: ANTHROPIC_API_KEY
    static var anthropic: String {
        ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"]
            ?? ""
    }

    /// Groq API key (Free tier, ultra-fast Llama 3)
    /// Set this via Xcode scheme environment variable: GROQ_API_KEY
    static var groq: String {
        ProcessInfo.processInfo.environment["GROQ_API_KEY"]
            ?? ""
    }

    // Key must be set via Config.plist (GEMINI_API_KEY) or GEMINI_API_KEY env var — see Services/AI/README_AI_PIPELINE.md
    /// Google Gemini API key
    /// Set this via Xcode scheme environment variable: GEMINI_API_KEY
    static var gemini: String {
        ProcessInfo.processInfo.environment["GEMINI_API_KEY"]
            ?? ""
    }

    /// OpenAI API key (GPT-4o)
    /// Set this via Config.plist (OPENAI_API_KEY) or Xcode scheme env var: OPENAI_API_KEY
    static var openAI: String {
        ProcessInfo.processInfo.environment["OPENAI_API_KEY"]
            ?? ""
    }
}
