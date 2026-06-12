//
//  LLMAnalysisService.swift
//  MedJourney
//

import Foundation

/// Cloud analysis built on the curated `health_summary.md` context: the Insights
/// deep summary and the home-screen daily greeting. Only the curated summary (or
/// a slice of it) is ever sent — never raw journal entries.
final class LLMAnalysisService {

    static let shared = LLMAnalysisService()

    /// When true, returns deterministic mock responses without hitting the network.
    /// Useful for unit tests, previews, and offline development.
    let dryRun: Bool

    init(dryRun: Bool = false) {
        self.dryRun = dryRun
    }

    // MARK: - Health Insights

    /// Generates a trend summary for the given window from the curated MD summary.
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

        let raw = try await LLMGateway.shared.complete(prompt: prompt, jsonMode: true)
        return try parseInsights(from: raw, timeRange: timeRange)
    }

    // MARK: - Daily Greeting

    /// Generates the home-screen greeting from the compact "Daily Summary Context" slice.
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

        let raw = try await LLMGateway.shared.complete(prompt: prompt, jsonMode: true)
        return try parseGreeting(from: raw)
    }

    // MARK: - Parsing

    private func parseInsights(from raw: String, timeRange: InsightTimeRange) throws -> HealthInsights {
        guard let data = Self.stripFences(raw).data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LLMError.parseError
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
        guard let data = Self.stripFences(raw).data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LLMError.parseError
        }
        return DailyGreeting(
            message: obj["message"] as? String ?? "Hello! How are you feeling today?",
            tone: DailyGreeting.Tone(rawValue: obj["tone"] as? String ?? "normal") ?? .normal
        )
    }

    /// Strips markdown code fences the model sometimes adds despite JSON mode.
    private static func stripFences(_ raw: String) -> String {
        raw.replacingOccurrences(of: "```json", with: "")
           .replacingOccurrences(of: "```", with: "")
           .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Mocks (dryRun)

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
