//
//  DailyGreeting.swift
//  MedJourney
//

import Foundation

/// A personalized daily greeting for the home screen.
struct DailyGreeting: Codable {

    /// The greeting text shown to the user.
    let message: String

    /// Tone of the greeting — escalates when critical conditions are flagged.
    let tone: Tone

    /// When the greeting was generated.
    let generatedAt: Date

    /// True when this instance was served from the local day-cache rather than freshly generated.
    let isFromCache: Bool

    init(
        message: String,
        tone: Tone = .normal,
        generatedAt: Date = Date(),
        isFromCache: Bool = false
    ) {
        self.message = message
        self.tone = tone
        self.generatedAt = generatedAt
        self.isFromCache = isFromCache
    }

    /// Returns a copy with `isFromCache` overridden (used when serving from cache).
    func markedFromCache(_ fromCache: Bool) -> DailyGreeting {
        DailyGreeting(message: message, tone: tone, generatedAt: generatedAt, isFromCache: fromCache)
    }

    /// Greeting tone, escalating with the user's current condition.
    enum Tone: String, Codable {
        case normal     // "Good morning! Your vitals have been stable this week."
        case alert      // gentle check-in on a recent flagged symptom
        case critical   // "You had a high fever yesterday — how are you feeling now?"
    }
}
