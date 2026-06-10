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

    /// Whether the briefing should play its typing animation on next display.
    /// Only true for a FRESHLY generated message (animate once). A message restored
    /// from cache — already seen by the user — shows in full instantly. The view
    /// flips this back to false via `TypingTextView.onFinished` after it plays.
    var shouldAnimateBriefing: Bool = false

    // MARK: - Briefing day-cache
    //
    // The welcome briefing must be generated ONCE per day, regardless of which path
    // produced it (on-device Foundation Models OR cloud greeting). We persist the
    // FINAL message here and restore it in `init()`, so tab re-appearances, sheet
    // dismissals, and SwiftUI view re-creation (which resets @State) never re-fire
    // the AI call when today's message already exists.

    private static let briefingMessageKey = "HomeBriefing.message"
    private static let briefingDateKey    = "HomeBriefing.generatedAt"

    /// True once we've produced (or restored) today's briefing — blocks re-generation
    /// even within the same session if the persisted message was cleared.
    private var hasLoadedToday = false

    // MARK: - Init

    init() {
        if let generated = UserDefaults.standard.object(forKey: Self.briefingDateKey) as? Date,
           Calendar.current.isDateInToday(generated),
           let cached = UserDefaults.standard.string(forKey: Self.briefingMessageKey),
           !cached.isEmpty {
            aiWelcomeMessage = cached
            hasLoadedToday   = true
            AIBriefingStore.shared.message = cached
        }
    }

    /// Persists the briefing for the rest of the day so it survives view re-creation.
    private func cacheBriefing(_ message: String) {
        UserDefaults.standard.set(message, forKey: Self.briefingMessageKey)
        UserDefaults.standard.set(Date(), forKey: Self.briefingDateKey)
    }

    // MARK: - Intents

    func loadWelcomeInsight(entries: [JournalEntry], anomalies: [VitalsAnomaly]) {
        // Skip if already loading, or we already have today's briefing (in memory or cached).
        guard !isLoadingWelcome, !hasLoadedToday, aiWelcomeMessage == nil else { return }

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

            // 0. Ensure health_summary.md has data before the greeting reads it.
            //    If entries came from seed / direct SwiftData insert (bypassing the
            //    normal saveEntry pipeline), the MD file would be empty and the LLM
            //    would produce a generic response. bootstrapFromEntries is a no-op
            //    once the file is already populated.
            let wasEmpty = await HealthSummaryManager.shared.isEffectivelyEmpty()
            await HealthSummaryManager.shared.bootstrapFromEntries(entries)
            // If the file was just bootstrapped, invalidate the stale DailySummaryService
            // cache so the greeting is re-generated with real data (not the cached generic one).
            if wasEmpty { DailySummaryService.shared.invalidateCache() }

            // Pull the curated MD context slice so BOTH paths can reference the user's
            // real documented history (conditions, lab trends, recent patterns) instead
            // of just loose tags — this is what makes the briefing specific, not generic.
            let mdContext = await HealthSummaryManager.shared.getDailySummaryContext()

            // 1. Try on-device Foundation Models first
            if FoundationModelsService.shared.isAvailable {
                message = await FoundationModelsService.shared.generateWelcomeInsight(
                    recentTags: recentTags,
                    anomalyMessages: anomalyMsgs,
                    yesterdayCompletion: yesterdayRate,
                    daysSinceLastEntry: daysSince,
                    healthContext: mdContext
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

            // Persist today's briefing so it survives view re-creation / tab switches.
            if let message, !message.isEmpty {
                self.cacheBriefing(message)
                self.hasLoadedToday = true
                // Freshly generated → play the typing animation exactly once.
                self.shouldAnimateBriefing = true
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
