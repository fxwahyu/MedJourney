//
//  HealthInsights.swift
//  MedJourney
//
//  Models/AI — Output of a trend-summary / Health Insights generation.
//
//  Built from health_summary.md only (never raw entries) by
//  LLMAnalysisService.generateHealthInsights(summary:timeRange:).
//

import Foundation

/// A multi-day trend summary plus any convergent alerts.
struct HealthInsights: Codable {

    /// The window this summary covers.
    let timeRange: InsightTimeRange

    /// Warm, plain-language narrative of the period's trends (non-diagnostic).
    let trendSummary: String

    /// Discrete signals worth surfacing to the user.
    let alerts: [HealthAlert]

    /// True when multiple critical signals converged — UI should nudge a doctor visit.
    let suggestDoctorVisit: Bool

    /// When the insights were generated.
    let generatedAt: Date

    init(
        timeRange: InsightTimeRange,
        trendSummary: String,
        alerts: [HealthAlert] = [],
        suggestDoctorVisit: Bool = false,
        generatedAt: Date = Date()
    ) {
        self.timeRange = timeRange
        self.trendSummary = trendSummary
        self.alerts = alerts
        self.suggestDoctorVisit = suggestDoctorVisit
        self.generatedAt = generatedAt
    }
}

/// A single surfaced signal inside a `HealthInsights` result.
struct HealthAlert: Identifiable, Codable, Hashable {

    let id: UUID

    /// Short observational message, e.g. "Blood pressure trended above range 4 of 7 days".
    let message: String

    /// Relative severity of the alert.
    let severity: Severity

    init(id: UUID = UUID(), message: String, severity: Severity) {
        self.id = id
        self.message = message
        self.severity = severity
    }

    /// Severity levels, ascending.
    enum Severity: String, Codable {
        case info
        case warning
        case critical
    }
}
