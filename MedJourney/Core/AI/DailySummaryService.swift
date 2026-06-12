//
//  DailySummaryService.swift
//  MedJourney
//

import Foundation

/// Generates and day-caches the home-screen greeting (cloud fallback path).
///
/// Only the compact "Daily Summary Context" slice of `health_summary.md` is sent
/// to the LLM — never the full file, never raw entries. The greeting is cached
/// for the calendar day and regenerated only when the day rolls over or the MD
/// file changed since the last generation.
final class DailySummaryService {

    static let shared = DailySummaryService()

    private let summaryManager: HealthSummaryManager
    private let llm: LLMAnalysisService
    private let defaults: UserDefaults

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

        let context = await summaryManager.getDailySummaryContext()
        let greeting = try await llm.generateDailyGreeting(summaryContext: context)

        let mdModified = await summaryManager.lastModified()
        cache(greeting, mdModifiedAt: mdModified)
        return greeting
    }

    /// Clears the cached greeting so the next call regenerates. Needed after
    /// `bootstrapFromEntries` writes real data into a previously empty file —
    /// otherwise the stale "no health context" greeting is served all day.
    func invalidateCache() {
        defaults.removeObject(forKey: cacheGeneratedAtKey)
        defaults.removeObject(forKey: cacheMessageKey)
        defaults.removeObject(forKey: cacheToneKey)
        defaults.removeObject(forKey: cacheMDModifiedKey)
    }

    func shouldRegenerateToday() -> Bool {
        guard let lastGenerated = defaults.object(forKey: cacheGeneratedAtKey) as? Date else {
            return true
        }
        if !Calendar.current.isDateInToday(lastGenerated) {
            return true
        }
        if let cachedMD = defaults.object(forKey: cacheMDModifiedKey) as? Date {
            return cachedMD < (currentMDModified() ?? cachedMD)
        }
        return false
    }

    // MARK: - Cache

    private func cachedGreeting() -> DailyGreeting? {
        guard let message = defaults.string(forKey: cacheMessageKey),
              let generatedAt = defaults.object(forKey: cacheGeneratedAtKey) as? Date else {
            return nil
        }
        let tone = DailyGreeting.Tone(rawValue: defaults.string(forKey: cacheToneKey) ?? "normal") ?? .normal
        return DailyGreeting(message: message, tone: tone, generatedAt: generatedAt, isFromCache: true)
    }

    private func cache(_ greeting: DailyGreeting, mdModifiedAt: Date?) {
        defaults.set(greeting.message, forKey: cacheMessageKey)
        defaults.set(greeting.tone.rawValue, forKey: cacheToneKey)
        defaults.set(greeting.generatedAt, forKey: cacheGeneratedAtKey)
        if let mdModifiedAt { defaults.set(mdModifiedAt, forKey: cacheMDModifiedKey) }
    }

    /// Synchronous read of the MD file's modification date for the quick staleness
    /// check (the actor's async `lastModified()` is the authoritative source).
    private func currentMDModified() -> Date? {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = docs.appendingPathComponent("health_summary.md")
        return try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date
    }
}
