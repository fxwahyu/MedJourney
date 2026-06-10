//
//  AIConfig.swift
//  MedJourney
//
//  Services/AI — Resolves the cloud LLM API key without hardcoding it in source.
//
//  Resolution order (first non-empty wins):
//  1. `Config.plist` → key `GEMINI_API_KEY`   (file is git-ignored; see README_AI_PIPELINE.md)
//  2. Environment variable `GEMINI_API_KEY`    (Xcode scheme)
//  3. The app's existing `APIKeys.gemini`      (back-compat fallback)
//
//  NOTE: Config.plist must be added to .gitignore and is NOT checked in.
//

import Foundation

/// Central configuration accessor for the AI pipeline.
///
/// Resolution order for every key (first non-empty, non-placeholder wins):
///  1. Config.plist  (git-ignored, add real keys here locally)
///  2. Environment variable  (Xcode scheme → Run → Environment Variables)
///  3. Empty string  (app will surface a clear error rather than a leaked key)
enum AIConfig {

    static var llmAPIKey: String    { resolve("GEMINI_API_KEY")    ?? "" }
    static var anthropicKey: String { resolve("ANTHROPIC_API_KEY") ?? "" }
    static var groqKey: String      { resolve("GROQ_API_KEY")      ?? "" }
    static var openAIKey: String    { resolve("OPENAI_API_KEY")    ?? "" }

    /// Resolves a key from Config.plist first, then the process environment.
    private static func resolve(_ key: String) -> String? {
        if let plistVal = configPlist?[key] as? String,
           !plistVal.isEmpty,
           !plistVal.hasPrefix("YOUR_") {
            print("🔑 [AIConfig] \(key) → Config.plist (\(plistVal.prefix(8))…)")
            return plistVal
        }
        if let envVal = ProcessInfo.processInfo.environment[key], !envVal.isEmpty {
            print("🔑 [AIConfig] \(key) → env var (\(envVal.prefix(8))…)")
            return envVal
        }
        print("🔑 [AIConfig] \(key) → ❌ NOT FOUND (Config.plist=\(configPlist == nil ? "nil" : "loaded"), env=missing)")
        return nil
    }

    /// Lazily-loaded `Config.plist` dictionary (nil if the file is absent).
    private static let configPlist: [String: Any]? = {
        guard let url = Bundle.main.url(forResource: "Config", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else {
            print("🔑 [AIConfig] Config.plist not found in Bundle.main (bundleURL=\(Bundle.main.bundleURL.lastPathComponent))")
            return nil
        }
        print("🔑 [AIConfig] Config.plist loaded from bundle (\(dict.keys.sorted().joined(separator: ", ")))")
        return dict
    }()
}
