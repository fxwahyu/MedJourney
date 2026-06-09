//
//  HomeViewModel.swift
//  MedJourney
//
//  Feature: Home — ViewModel for HomeTabView
//

import SwiftUI

/// State and business logic for HomeTabView.
///
/// AI welcome insight pipeline:
///   1. Try Foundation Models (on-device, private, instant)
///   2. If unavailable, fall back to a cloud greeting generated from the curated
///      `health_summary.md` "Daily Summary Context" slice (DailySummaryService) —
///      NOT a fresh cloud call built from local stats, keeping token usage minimal
///      and giving the cloud only the small, already-curated context it needs.
@Observable
final class HomeViewModel {

    // MARK: - State

    /// Warm personalised sentence for the AI Daily Briefing card.
    /// `nil` while loading — view shows the loader state.
    var aiWelcomeMessage: String? = nil

    /// True while either Foundation Models or the curated cloud greeting is generating.
    var isLoadingWelcome: Bool = false

    // MARK: - Intents

    func loadWelcomeInsight(entries: [JournalEntry], anomalies: [VitalsAnomaly]) {
        guard !isLoadingWelcome, aiWelcomeMessage == nil else { return }

        isLoadingWelcome = true

        let recentTags  = Array(entries.prefix(10).flatMap(\.aiTags).prefix(6))
        let anomalyMsgs = anomalies.map(\.message)
        let daysSince   = entries.first.map {
            Calendar.current.dateComponents([.day], from: $0.createdAt, to: Date()).day ?? 0
        }
        let yesterday     = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        let yesterdayRate = ChecklistHistoryStore.shared.load()
            .first { Calendar.current.isDate($0.date, inSameDayAs: yesterday) }?.completionRate

        Task { @MainActor in
            var message: String? = nil

            // 1. Try on-device Foundation Models first
            if FoundationModelsService.shared.isAvailable {
                message = await FoundationModelsService.shared.generateWelcomeInsight(
                    recentTags: recentTags,
                    anomalyMessages: anomalyMsgs,
                    yesterdayCompletion: yesterdayRate,
                    daysSinceLastEntry: daysSince
                )
            }

            // 2. Cloud fallback if Foundation Models unavailable or returned nil —
            // generated from the curated MD "Daily Summary Context" slice only
            // (DailySummaryService also day-caches it, so this rarely costs a token).
            if message == nil {
                print("🤖 [HomeViewModel] Foundation Models unavailable — falling back to MD-curated greeting")
                if let greeting = try? await DailySummaryService.shared.generateGreeting() {
                    message = greeting.message
                }
            }

            withAnimation(.easeIn(duration: 0.3)) {
                self.aiWelcomeMessage = message
                self.isLoadingWelcome = false
            }
            // Share with Journal mood sheet so it can reuse this message
            AIBriefingStore.shared.message = message
        }
    }
}
