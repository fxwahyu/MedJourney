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
//  Backend: Google Gemini (matches the app's existing LLMTagService /
//  ChecklistGenerationService). API key is read from Config.plist or the environment,
//  never hardcoded.
//
//  TODO: integrate with existing LLMTagService / ChecklistGenerationService to
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

    /// Set to `true` during development to return mock responses without hitting the
    /// Gemini API. Flip back to `false` before testing real AI output or submitting.
    #if DEBUG
    static let useDryRunForDevelopment = false  // ← set true to use mock responses during UI dev
    #endif

    static let shared: LLMAnalysisService = {
        #if DEBUG
        return LLMAnalysisService(dryRun: useDryRunForDevelopment)
        #else
        return LLMAnalysisService()
        #endif
    }()

    /// When true, returns deterministic mock responses without hitting the network.
    /// Useful for unit tests, previews, and offline development.
    let dryRun: Bool

    /// - Parameter dryRun: Return mocks instead of calling the LLM.
    ///
    /// Note: this service holds no API key. All network calls route through
    /// `LLMGateway`, which resolves the provider + key (Groq → Gemini fallback).
    init(dryRun: Bool = false) {
        self.dryRun = dryRun
        print("🧠 [LLMAnalysisService] init — dryRun=\(dryRun) (transport via LLMGateway)")
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

        let raw = try await callLLM(prompt: prompt, jsonMode: true)
        return try parseCheckupAnalysis(from: raw, rawText: extractedText)
    }

    // MARK: - Health Insights (from MD summary only)

    /// Generates a 7–30 day trend summary from the curated MD summary (never raw entries).
    func generateHealthInsights(summary: String, timeRange: InsightTimeRange) async throws -> HealthInsights {
        if dryRun { return Self.mockInsights(timeRange: timeRange) }

        let prompt = """
        You are MedCare AI. Using the curated health summary below, write a warm, SPECIFIC trend summary for the past \(timeRange.label) and return ONLY valid JSON (no fences):

        {
          "trend_summary": "warm, plain-language narrative that references the user's actual documented conditions, lab trends, vitals, and recent symptoms by name",
          "alerts": [{"message": "specific observational signal drawn from the summary", "severity": "info|warning|critical"}],
          "suggest_doctor_visit": false
        }

        WRITING RULES:
        - Be SPECIFIC. Reference the user's actual data: name their documented conditions, cite lab markers and how they're trending (e.g. "your HbA1c has improved from 8.2% to 7.1%"), mention recurring symptoms and vital patterns. A generic summary is a failure.
        - The conditions and lab values in the summary are the user's OWN documented medical history — you MAY reference them by name. You are summarising known history, NOT making a new diagnosis.
        - Do NOT invent or imply any NEW condition that is not already written in the summary.
        - "alerts" should surface the most important real signals from the summary (e.g. recurring dizziness, an elevated marker), each tied to actual data.
        - Set suggest_doctor_visit to true ONLY if multiple concerning signals converge.
        - Warm and encouraging tone, never alarming.

        Curated health summary:
        \(summary)
        """

        let raw = try await callLLM(prompt: prompt, jsonMode: true)
        return try parseInsights(from: raw, timeRange: timeRange)
    }

    // MARK: - Daily greeting (from the small Daily Summary Context slice only)

    /// Generates the home-screen greeting from the compact "Daily Summary Context" slice.
    /// Escalates tone when the context signals critical conditions.
    func generateDailyGreeting(summaryContext: String) async throws -> DailyGreeting {
        if dryRun { return Self.mockGreeting() }

        let prompt = """
        You are MedCare AI, a warm health companion. Based on the context below, write a personalized, SPECIFIC home-screen greeting and return ONLY valid JSON (no fences):

        {
          "message": "EXACTLY TWO sentences (about 30–40 words). Sentence 1 names the user's specific recent situation; sentence 2 gives a brief, useful, actionable takeaway.",
          "tone": "normal|alert|critical"
        }

        WRITING RULES:
        - The message must be TWO sentences. Sentence 1: warmly name a concrete detail from the context (a recent symptom like the dizziness, a lab trend like improving blood sugar, or how their week went). Sentence 2: a short useful takeaway — gentle encouragement, one thing to watch, or a nudge worth acting on today.
        - Be SPECIFIC to this user. A generic "hope you're well" greeting is a failure.
        - The conditions and values in the context are the user's OWN documented history — you MAY mention them. This is not a new diagnosis.
        - Do NOT invent any NEW condition not present in the context.
        - Tone: "critical" for a serious recent signal, "alert" for a mild recent flag, "normal" when stable/improving.
        - Warm and caring, never clinical or alarming.

        Daily summary context:
        \(summaryContext)
        """

        let raw = try await callLLM(prompt: prompt, jsonMode: true)
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

        let raw = try await callLLM(prompt: prompt, jsonMode: true)
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

    // MARK: - LLM transport (delegates to the single gate)

    /// Thin wrapper around the app-wide `LLMGateway`. All provider routing, fallback,
    /// and retry logic lives in the gateway — this just bridges the gateway's error
    /// type to `LLMAnalysisError` so the Insights deep-summary flow can keep catching
    /// its specific cases (`.missingAPIKey`, `.apiError`, `.parseError`).
    private func callLLM(prompt: String, jsonMode: Bool) async throws -> String {
        do {
            return try await LLMGateway.shared.complete(prompt: prompt, jsonMode: jsonMode)
        } catch let error as LLMGatewayError {
            throw error.asLLMAnalysisError
        }
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
        let stripped = Self.strip(raw)
        print("🧠 [LLMAnalysisService] parseInsights — strippedLen=\(stripped.count), prefix: \(stripped.prefix(120))")
        guard let data = stripped.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("🧠 [LLMAnalysisService] ❌ parseInsights failed — JSONSerialization returned nil or not [String:Any]")
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
