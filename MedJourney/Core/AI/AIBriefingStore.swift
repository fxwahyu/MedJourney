//
//  AIBriefingStore.swift
//  MedJourney
//
//  Shared singleton that holds the AI daily briefing message generated on the Home screen.
//  The Journal mood sheet reads from here instead of generating a separate prompt,
//  so the user sees a consistent message across both surfaces.
//

import Foundation

@Observable
final class AIBriefingStore {
    static let shared = AIBriefingStore()
    private init() {}

    /// The briefing message last generated for the current session.
    /// `nil` means not yet ready — callers should show a loading state or placeholder.
    var message: String? = nil
}
