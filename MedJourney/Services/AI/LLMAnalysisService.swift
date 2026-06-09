//
//  LLMAnalysisService.swift
//  MedJourney
//
//  Services/AI — Layer 2: the single funnel for ALL cloud LLM calls.
//
//  Token strategy: this service is only ever handed (a) OCR'd checkup text once, or
//  (b) the curated health_summary.md slice — never raw journal history. That's how
//  the pipeline keeps token usage ~90% below sending entries directly.
//
//  Backend: Google Gemini (matches the app's existing GeminiTagService /
//  ChecklistGenerationService). API key is read from Config.plist or the environment,
//  never hardcoded.
//
//  TODO: integrate with existing GeminiTagService / ChecklistGenerationService to
//  share a single Gemini transport if desired — kept separate here for a clean scaffold.
//

import Foundation

/// Errors thrown by cloud LLM analysis.
enum LLMAnalysisError: LocalizedError {
    case missingAPIKey
    case apiError(Int)
    case parseError

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "No LLM API key configured (Config.plist / environment)."
        case .apiError(let code): return "LLM API error: HTTP \(code)"
        case .parseError: return "Failed to parse LLM response."
        }
    }
}

/// All outbound cloud LLM calls for the AI pipeline funnel through this type.
final class LLMAnalysisService {

    static let shared = LLMAnalysisService()

    private let apiKey: String
    private let session: URLSession

    /// When true, returns deterministic mock responses without hitting the network.
    /// Useful for unit tests, previews, and offline development.
    let dryRun: Bool

    /// - Parameters:
    ///   - apiKey: Resolved LLM key. Defaults to `AIConfig.llmAPIKey` (Config.plist → env → fallback).
    ///   - dryRun: Return mocks instead of calling the API.
    init(apiKey: String = AIConfig.llmAPIKey, session: URLSession = .shared, dryRun: Bool = false) {
        self.apiKey = apiKey
        self.session = session
        self.dryRun = dryRun
    }

    // MARK: - Checkup deep analysis

    /// Sends OCR'd checkup text to the LLM once and returns structured analysis.
    /// This is the only call that sees the raw checkup text.
    func analyzeCheckup(extractedText: String) async throws -> CheckupAnalysis {
        if dryRun { return Self.mockCheckupAnalysis(rawText: extractedText) }

        let prompt = """
        You are MedCare AI, a warm health companion. Analyze the checkup text below and return ONLY a valid JSON object (no markdown fences):

        {
          "summary": "2-3 warm, non-diagnostic sentences about the overall results",
          "flagged_markers": [
            {"name": "Hemoglobin", "value": "11.2", "unit": "g/dL", "normal_range": "13.5-17.5", "is_abnormal": true, "trend": "stable"}
          ],
          "recommendations": ["general wellness habit", "another habit"],
          "daily_checklist": [{"emoji": "💧", "text": "Drink 2.5L water daily"}]
        }

        SAFETY RULES:
        - Do NOT name, diagnose, or suggest any specific medical condition or disease.
        - Use observational language only ("below the reference range", not "anemia").
        - Frame abnormal results as "worth discussing with your doctor".
        - "trend" must be one of: improving, stable, worsening.

        Checkup text:
        \(extractedText)
        """

        let raw = try await callGemini(prompt: prompt, jsonMode: true)
        return try parseCheckupAnalysis(from: raw, rawText: extractedText)
    }

    // MARK: - Health Insights (from MD summary only)

    /// Generates a 7–30 day trend summary from the curated MD summary (never raw entries).
    func generateHealthInsights(summary: String, timeRange: InsightTimeRange) async throws -> HealthInsights {
        if dryRun { return Self.mockInsights(timeRange: timeRange) }

        let prompt = """
        You are MedCare AI. Using ONLY the curated health summary below, write a warm trend summary for the past \(timeRange.label) and return ONLY valid JSON (no fences):

        {
          "trend_summary": "warm, plain-language, non-diagnostic narrative",
          "alerts": [{"message": "observational signal", "severity": "info|warning|critical"}],
          "suggest_doctor_visit": false
        }

        SAFETY RULES:
        - Describe patterns and frequencies only — never name or imply a diagnosis.
        - Set suggest_doctor_visit to true ONLY if multiple critical signals converge.

        Curated health summary:
        \(summary)
        """

        let raw = try await callGemini(prompt: prompt, jsonMode: true)
        return try parseInsights(from: raw, timeRange: timeRange)
    }

    // MARK: - Daily greeting (from the small Daily Summary Context slice only)

    /// Generates the home-screen greeting from the compact "Daily Summary Context" slice.
    /// Escalates tone when the context signals critical conditions.
    func generateDailyGreeting(summaryContext: String) async throws -> DailyGreeting {
        if dryRun { return Self.mockGreeting() }

        let prompt = """
        You are MedCare AI, a warm health companion. Based ONLY on the brief context below, write a personalized home-screen greeting and return ONLY valid JSON (no fences):

        {
          "message": "one warm, caring greeting (max 2 sentences)",
          "tone": "normal|alert|critical"
        }

        Tone guidance:
        - "critical": a serious recent signal (e.g. high fever, chest pain) — gently check in, e.g. "You had a high fever yesterday — how are you feeling now?"
        - "alert": a mild recent flag worth a soft mention.
        - "normal": stable — e.g. "Good morning! Your vitals have been stable this week."

        SAFETY RULES:
        - Warm and caring, never clinical or alarming.
        - Do NOT name or imply any diagnosis.

        Daily summary context:
        \(summaryContext)
        """

        let raw = try await callGemini(prompt: prompt, jsonMode: true)
        return try parseGreeting(from: raw)
    }

    // MARK: - Daily tags (cloud fallback only)

    /// Cloud fallback for journal tag extraction.
    /// NOTE: preserving existing fallback logic — this is invoked ONLY when the
    /// on-device Foundation Models path is unavailable (decided upstream by the
    /// pipeline via FoundationModelsService). It must not be called otherwise.
    func generateDailyTags(journalText: String) async throws -> [HealthTag] {
        if dryRun {
            return [HealthTag(label: "low energy", category: .symptom, source: .llm)]
        }

        let prompt = """
        Extract 2–6 short, observational health tags from this journal text.
        Return ONLY a JSON array of lowercase strings (e.g. ["headache","fatigue"]).
        Do NOT name or imply any diagnosis — symptom/observation words only.

        Text: \(journalText.prefix(500))
        """

        let raw = try await callGemini(prompt: prompt, jsonMode: true)
        let cleaned = raw
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = cleaned.data(using: .utf8),
              let labels = try? JSONSerialization.jsonObject(with: data) as? [String] else {
            throw LLMAnalysisError.parseError
        }
        return labels.prefix(6).map { HealthTag(label: $0, category: .symptom, source: .llm) }
    }

    // MARK: - Gemini transport

    /// Low-level Gemini call. Mirrors the existing GeminiTagService transport.
    private func callGemini(prompt: String, jsonMode: Bool) async throws -> String {
        guard !apiKey.isEmpty, apiKey != "YOUR_GEMINI_API_KEY_HERE" else {
            throw LLMAnalysisError.missingAPIKey
        }

        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-goog-api-key")

        var body: [String: Any] = ["contents": [["parts": [["text": prompt]]]]]
        if jsonMode { body["generationConfig"] = ["responseMimeType": "application/json"] }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw LLMAnalysisError.apiError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let content = candidates.first?["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String else {
            throw LLMAnalysisError.parseError
        }
        return text
    }

    // MARK: - Parsing

    private func parseCheckupAnalysis(from raw: String, rawText: String) throws -> CheckupAnalysis {
        guard let data = Self.strip(raw).data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LLMAnalysisError.parseError
        }
        let markers: [LabMarker] = (obj["flagged_markers"] as? [[String: Any]] ?? []).map { m in
            LabMarker(
                name: m["name"] as? String ?? "—",
                value: m["value"] as? String ?? "—",
                unit: m["unit"] as? String ?? "",
                normalRange: m["normal_range"] as? String ?? "—",
                isAbnormal: m["is_abnormal"] as? Bool ?? false,
                trend: LabMarker.Trend(rawValue: m["trend"] as? String ?? "stable") ?? .stable
            )
        }
        let checklist: [ChecklistGenerationItem] = (obj["daily_checklist"] as? [[String: Any]] ?? []).map {
            ChecklistGenerationItem(emoji: $0["emoji"] as? String ?? "✅", text: $0["text"] as? String ?? "")
        }
        return CheckupAnalysis(
            summary: obj["summary"] as? String ?? "",
            flaggedMarkers: markers,
            recommendations: obj["recommendations"] as? [String] ?? [],
            dailyChecklist: checklist,
            rawExtractedText: rawText
        )
    }

    private func parseInsights(from raw: String, timeRange: InsightTimeRange) throws -> HealthInsights {
        guard let data = Self.strip(raw).data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LLMAnalysisError.parseError
        }
        let alerts: [HealthAlert] = (obj["alerts"] as? [[String: Any]] ?? []).map {
            HealthAlert(
                message: $0["message"] as? String ?? "",
                severity: HealthAlert.Severity(rawValue: $0["severity"] as? String ?? "info") ?? .info
            )
        }
        return HealthInsights(
            timeRange: timeRange,
            trendSummary: obj["trend_summary"] as? String ?? "",
            alerts: alerts,
            suggestDoctorVisit: obj["suggest_doctor_visit"] as? Bool ?? false
        )
    }

    private func parseGreeting(from raw: String) throws -> DailyGreeting {
        guard let data = Self.strip(raw).data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LLMAnalysisError.parseError
        }
        return DailyGreeting(
            message: obj["message"] as? String ?? "Hello! How are you feeling today?",
            tone: DailyGreeting.Tone(rawValue: obj["tone"] as? String ?? "normal") ?? .normal
        )
    }

    /// Strips markdown code fences the model sometimes adds despite JSON mode.
    private static func strip(_ raw: String) -> String {
        raw.replacingOccurrences(of: "```json", with: "")
           .replacingOccurrences(of: "```", with: "")
           .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Mocks (dryRun)

    private static func mockCheckupAnalysis(rawText: String) -> CheckupAnalysis {
        CheckupAnalysis(
            summary: "Your results look mostly within typical ranges, with one value worth discussing with your doctor.",
            flaggedMarkers: [LabMarker(name: "Hemoglobin", value: "11.2", unit: "g/dL", normalRange: "13.5–17.5", isAbnormal: true, trend: .stable)],
            recommendations: ["Stay hydrated", "Aim for iron-rich foods"],
            dailyChecklist: [ChecklistGenerationItem(emoji: "💧", text: "Drink 2.5L water daily")],
            rawExtractedText: rawText
        )
    }

    private static func mockInsights(timeRange: InsightTimeRange) -> HealthInsights {
        HealthInsights(
            timeRange: timeRange,
            trendSummary: "Over the past \(timeRange.label), your readings have been fairly steady with a couple of mild fluctuations.",
            alerts: [HealthAlert(message: "Mentioned headaches on a few days", severity: .info)],
            suggestDoctorVisit: false
        )
    }

    private static func mockGreeting() -> DailyGreeting {
        DailyGreeting(message: "Good morning! Your vitals have been stable this week. 🌤️", tone: .normal)
    }
}
