//
//  DailySummaryService.swift
//  MedJourney
//
//  Services/AI — Powers the home-screen daily greeting card.
//
//  Token strategy: only the small "Daily Summary Context" slice of health_summary.md
//  is sent to the LLM here — never the full file, never raw entries.
//
//  Caching: the generated greeting is cached for the day and only regenerated when
//  (a) the calendar day has rolled over, or (b) the MD file changed since last generation.
//
//  TODO: call `generateGreeting()` from the Home view's onAppear or `.task` modifier
//  (e.g. in HomeTabView / HomeViewModel).
//

import Foundation

/// Generates and day-caches the home-screen greeting.
/// Not actor-isolated — `UserDefaults` and `FileManager` are thread-safe, and the
/// only async work hops to the `HealthSummaryManager` actor and `LLMAnalysisService`.
final class DailySummaryService {

    static let shared = DailySummaryService()

    private let summaryManager: HealthSummaryManager
    private let llm: LLMAnalysisService
    private let defaults: UserDefaults

    // Cache keys.
    private let cacheMessageKey = "DailyGreeting.message"
    private let cacheToneKey = "DailyGreeting.tone"
    private let cacheGeneratedAtKey = "DailyGreeting.generatedAt"
    private let cacheMDModifiedKey = "DailyGreeting.mdModifiedAt"

    init(
        summaryManager: HealthSummaryManager = .shared,
        llm: LLMAnalysisService = .shared,
        defaults: UserDefaults = .standard
    ) {
        self.summaryManager = summaryManager
        self.llm = llm
        self.defaults = defaults
    }

    /// Returns today's greeting — cached if still valid, otherwise freshly generated.
    func generateGreeting() async throws -> DailyGreeting {
        if !shouldRegenerateToday(), let cached = cachedGreeting() {
            return cached.markedFromCache(true)
        }

        // Pull only the compact context slice — NOT the full MD file.
        let context = await summaryManager.getDailySummaryContext()
        let greeting = try await llm.generateDailyGreeting(summaryContext: context)

        let mdModified = await summaryManager.lastModified()
        cache(greeting, mdModifiedAt: mdModified)
        return greeting
    }

    /// True if the greeting should be regenerated:
    /// - last generation was before today (calendar rollover), OR
    /// - the MD file changed since the cached greeting was generated, OR
    /// - there is no cached greeting yet.
    func shouldRegenerateToday() -> Bool {
        guard let lastGenerated = defaults.object(forKey: cacheGeneratedAtKey) as? Date else {
            return true // never generated
        }
        if !Calendar.current.isDateInToday(lastGenerated) {
            return true // new day
        }
        // MD changed since last generation?
        if let cachedMD = defaults.object(forKey: cacheMDModifiedKey) as? Date {
            // Compared against the cached snapshot; the caller refreshes after generation.
            // A later MD modification time than what we cached means stale.
            return cachedMD < (currentMDModifiedSync() ?? cachedMD)
        }
        return false
    }

    // MARK: - Cache helpers

    /// Reads the cached greeting from UserDefaults, if present.
    private func cachedGreeting() -> DailyGreeting? {
        guard let message = defaults.string(forKey: cacheMessageKey),
              let generatedAt = defaults.object(forKey: cacheGeneratedAtKey) as? Date else {
            return nil
        }
        let tone = DailyGreeting.Tone(rawValue: defaults.string(forKey: cacheToneKey) ?? "normal") ?? .normal
        return DailyGreeting(message: message, tone: tone, generatedAt: generatedAt, isFromCache: true)
    }

    /// Persists the greeting and the MD modification time it was generated against.
    private func cache(_ greeting: DailyGreeting, mdModifiedAt: Date?) {
        defaults.set(greeting.message, forKey: cacheMessageKey)
        defaults.set(greeting.tone.rawValue, forKey: cacheToneKey)
        defaults.set(greeting.generatedAt, forKey: cacheGeneratedAtKey)
        if let mdModifiedAt { defaults.set(mdModifiedAt, forKey: cacheMDModifiedKey) }
    }

    /// Synchronous best-effort read of the MD file's modification date for the
    /// `shouldRegenerateToday()` quick check (the actor's async API is authoritative).
    private func currentMDModifiedSync() -> Date? {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = docs.appendingPathComponent("health_summary.md")
        return try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date
    }
}
