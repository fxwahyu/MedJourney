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

    // MARK: - Briefing cache (regenerate-on-change)
    //
    // The briefing is regenerated ONLY when the user's health data actually changed —
    // i.e. `health_summary.md` was modified by a new journal/checkup save. Otherwise
    // the last saved briefing is restored and kept on screen. We persist the FINAL
    // message alongside the MD modification date it was generated against, and compare
    // that against the current MD mtime on each load to decide regenerate-vs-reuse.
    // This survives view re-creation, tab switches, and app relaunches.

    private static let briefingMessageKey = "HomeBriefing.message"
    private static let briefingMDModKey   = "HomeBriefing.mdModifiedAt"

    /// MD modification date the currently-displayed briefing was generated against.
    /// `nil` until a briefing exists. Used to detect new entries since last generation.
    private var briefingMDModified: Date?

    // MARK: - Init

    init() {
        if let cached = UserDefaults.standard.string(forKey: Self.briefingMessageKey),
           !cached.isEmpty {
            aiWelcomeMessage   = cached
            briefingMDModified = UserDefaults.standard.object(forKey: Self.briefingMDModKey) as? Date
            // Restored from cache → already seen, show in full without re-animating.
            shouldAnimateBriefing = false
            AIBriefingStore.shared.message = cached
        }
    }

    /// Persists the briefing and the MD mtime it was generated against, so future
    /// loads can tell whether the health data has changed since.
    private func cacheBriefing(_ message: String, mdModified: Date?) {
        briefingMDModified = mdModified
        UserDefaults.standard.set(message, forKey: Self.briefingMessageKey)
        if let mdModified {
            UserDefaults.standard.set(mdModified, forKey: Self.briefingMDModKey)
        }
    }

    // MARK: - Intents

    func loadWelcomeInsight(entries: [JournalEntry], anomalies: [VitalsAnomaly]) {
        // Skip only if a generation is already in flight. We no longer block on
        // "already loaded today" — regeneration is gated by MD changes below.
        guard !isLoadingWelcome else { return }

        // Show the loader ONLY on the very first load (nothing to display yet). When a
        // briefing already exists, keep it on screen and regenerate silently underneath
        // so the card never flickers back to a loading state.
        if aiWelcomeMessage == nil { isLoadingWelcome = true }

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

            // Gate regeneration on whether the health data actually changed. The MD file
            // is only modified when a new journal/checkup is saved (or just bootstrapped),
            // so an unchanged mtime means there's nothing new to say — keep the last
            // briefing exactly as-is.
            let currentMD = await HealthSummaryManager.shared.lastModified()
            if let existing = self.aiWelcomeMessage, !existing.isEmpty,
               let lastMD = self.briefingMDModified, let currentMD,
               currentMD <= lastMD {
                self.isLoadingWelcome = false
                AIBriefingStore.shared.message = existing
                return
            }

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

            // Persist the new briefing so it survives view re-creation / tab switches.
            // On a generation FAILURE (message nil/empty), keep the previous briefing on
            // screen rather than clearing it — the card must never go blank once shown.
            if let message, !message.isEmpty {
                self.cacheBriefing(message, mdModified: currentMD)
                // Freshly generated → play the typing animation exactly once.
                self.shouldAnimateBriefing = true
                withAnimation(.easeIn(duration: 0.3)) {
                    self.aiWelcomeMessage = message
                }
            }
            self.isLoadingWelcome = false
            // Share with Journal mood sheet so it can reuse this message
            AIBriefingStore.shared.message = self.aiWelcomeMessage
        }
    }
}
