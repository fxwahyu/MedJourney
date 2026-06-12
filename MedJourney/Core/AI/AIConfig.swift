//
//  AIConfig.swift
//  MedJourney
//

import Foundation

/// Resolves cloud LLM API keys without hardcoding them in source.
///
/// Resolution order (first non-empty, non-placeholder wins):
///  1. `Config.plist` — git-ignored, add real keys there locally
///  2. Environment variable — Xcode scheme → Run → Environment Variables
enum AIConfig {

    static var geminiKey: String { resolve("GEMINI_API_KEY") ?? "" }
    static var groqKey: String   { resolve("GROQ_API_KEY") ?? "" }

    private static func resolve(_ key: String) -> String? {
        if let value = configPlist?[key] as? String, !value.isEmpty, !value.hasPrefix("YOUR_") {
            return value
        }
        if let value = ProcessInfo.processInfo.environment[key], !value.isEmpty {
            return value
        }
        return nil
    }

    private static let configPlist: [String: Any]? = {
        guard let url = Bundle.main.url(forResource: "Config", withExtension: "plist"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
    }()
}
