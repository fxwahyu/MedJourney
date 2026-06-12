//
//  HomeViewModel.swift
//  MedJourney
//

import SwiftUI
import SwiftData

/// State and business logic for `HomeTabView`.
///
/// Daily briefing pipeline: try on-device Foundation Models first; fall back to
/// a cloud greeting generated from the curated `health_summary.md` context slice.
/// The briefing is regenerated only when the health data actually changed (the MD
/// file's modification date moved); otherwise the cached one is restored — this
/// survives view re-creation, tab switches, and app relaunches.
@Observable
final class HomeViewModel {

    // MARK: - State

    /// `nil` while loading — the view shows its loader state.
    var aiWelcomeMessage: String?
    var isLoadingWelcome = false

    /// True only for a freshly generated briefing, so the typing animation plays
    /// exactly once. Cached messages (already seen) show in full instantly; the
    /// view flips this back via `TypingTextView.onFinished`.
    var shouldAnimateBriefing = false

    // MARK: - Private

    private static let briefingMessageKey = "HomeBriefing.message"
    private static let briefingMDModKey = "HomeBriefing.mdModifiedAt"

    /// MD modification date the displayed briefing was generated against.
    private var briefingMDModified: Date?

    init() {
        if let cached = UserDefaults.standard.string(forKey: Self.briefingMessageKey), !cached.isEmpty {
            aiWelcomeMessage = cached
            briefingMDModified = UserDefaults.standard.object(forKey: Self.briefingMDModKey) as? Date
            shouldAnimateBriefing = false
            AIBriefingStore.shared.message = cached
        }
    }

    // MARK: - Daily Briefing

    func loadWelcomeInsight(entries: [JournalEntry], anomalies: [VitalsAnomaly]) {
        guard !isLoadingWelcome else { return }

        // Show the loader only on the very first load; when a briefing already
        // exists, keep it on screen and regenerate silently underneath.
        if aiWelcomeMessage == nil { isLoadingWelcome = true }

        let recentTags = Array(entries.prefix(10).flatMap(\.aiTags).prefix(6))
        let anomalyMessages = anomalies.map(\.message)
        let daysSince = entries.first.map {
            Calendar.current.dateComponents([.day], from: $0.createdAt, to: Date()).day ?? 0
        }
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        let yesterdayRate = ChecklistHistoryStore.shared.load()
            .first { Calendar.current.isDate($0.date, inSameDayAs: yesterday) }?.completionRate

        Task { @MainActor in
            // Make sure health_summary.md has data before the greeting reads it —
            // seeded entries bypass the normal save pipeline and leave it empty.
            let wasEmpty = await HealthSummaryManager.shared.isEffectivelyEmpty()
            await HealthSummaryManager.shared.bootstrapFromEntries(entries)
            if wasEmpty { DailySummaryService.shared.invalidateCache() }

            // Unchanged MD modification date means no new health data — keep the
            // current briefing as-is.
            let currentMD = await HealthSummaryManager.shared.lastModified()
            if let existing = self.aiWelcomeMessage, !existing.isEmpty,
               let lastMD = self.briefingMDModified, let currentMD,
               currentMD <= lastMD {
                self.isLoadingWelcome = false
                AIBriefingStore.shared.message = existing
                return
            }

            let mdContext = await HealthSummaryManager.shared.getDailySummaryContext()

            var message: String?
            if FoundationModelsService.shared.isAvailable {
                message = await FoundationModelsService.shared.generateWelcomeInsight(
                    recentTags: recentTags,
                    anomalyMessages: anomalyMessages,
                    yesterdayCompletion: yesterdayRate,
                    daysSinceLastEntry: daysSince,
                    healthContext: mdContext
                )
            }
            if message == nil {
                message = try? await DailySummaryService.shared.generateGreeting().message
            }

            // On failure keep the previous briefing — the card must never go blank.
            if let message, !message.isEmpty {
                self.cacheBriefing(message, mdModified: currentMD)
                self.shouldAnimateBriefing = true
                withAnimation(.easeIn(duration: 0.3)) {
                    self.aiWelcomeMessage = message
                }
            }
            self.isLoadingWelcome = false
            AIBriefingStore.shared.message = self.aiWelcomeMessage
        }
    }

    private func cacheBriefing(_ message: String, mdModified: Date?) {
        briefingMDModified = mdModified
        UserDefaults.standard.set(message, forKey: Self.briefingMessageKey)
        if let mdModified {
            UserDefaults.standard.set(mdModified, forKey: Self.briefingMDModKey)
        }
    }

    // MARK: - Daily Checklist Reset

    /// Once per calendar day: records yesterday's completion into the history
    /// store, then unchecks every item for the new day.
    func resetChecklistIfNeeded(items: [ChecklistItem]) {
        guard !items.isEmpty else { return }

        let lastReset = UserDefaults.standard.object(forKey: "checklistLastReset") as? Date
        guard lastReset == nil || !Calendar.current.isDateInToday(lastReset!) else { return }

        let completed = items.filter(\.isChecked).count
        ChecklistHistoryStore.shared.recordToday(total: items.count, completed: completed)
        if completed > 0 {
            UserDefaults.standard.set(Date(), forKey: "checklistLastSaved")
        }
        for item in items { item.isChecked = false }
        UserDefaults.standard.set(Date(), forKey: "checklistLastReset")
    }
}
