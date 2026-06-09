//
//  InsightTimeRange.swift
//  MedJourney
//
//  Models/AI — The window of history a Health Insights request covers.
//

import Foundation

/// Time window for an AI Health Insights generation.
enum InsightTimeRange: Codable, Hashable {

    /// Last 7 days.
    case sevenDays

    /// Last 30 days.
    case thirtyDays

    /// An explicit custom interval.
    case custom(DateInterval)

    /// Human-readable label used in prompts and UI (e.g. "7 days").
    var label: String {
        switch self {
        case .sevenDays: return "7 days"
        case .thirtyDays: return "30 days"
        case .custom(let interval):
            let days = Int(interval.duration / 86_400)
            return "\(days) days"
        }
    }

    /// The concrete date interval ending now, used to filter history.
    var dateInterval: DateInterval {
        switch self {
        case .sevenDays:
            return DateInterval(start: Date().addingTimeInterval(-7 * 86_400), end: Date())
        case .thirtyDays:
            return DateInterval(start: Date().addingTimeInterval(-30 * 86_400), end: Date())
        case .custom(let interval):
            return interval
        }
    }
}
