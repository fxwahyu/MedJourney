//
//  InsightTimeRange.swift
//  MedJourney
//

import Foundation

/// Time window an AI Health Insights generation covers.
enum InsightTimeRange: Codable, Hashable {
    case sevenDays
    case thirtyDays
    case custom(DateInterval)

    /// Human-readable label used in prompts and UI (e.g. "7 days").
    var label: String {
        switch self {
        case .sevenDays:  return "7 days"
        case .thirtyDays: return "30 days"
        case .custom(let interval):
            return "\(Int(interval.duration / 86_400)) days"
        }
    }
}
