//
//  AIBriefingStore.swift
//  MedJourney
//

import Foundation

/// Holds the daily briefing generated on the Home screen so the Journal mood
/// sheet can reuse it — one generation, consistent message across both surfaces.
@Observable
final class AIBriefingStore {
    static let shared = AIBriefingStore()
    private init() {}

    /// `nil` until the Home screen finishes generating the briefing.
    var message: String?
}
