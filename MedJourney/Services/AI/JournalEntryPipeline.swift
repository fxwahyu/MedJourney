//
//  JournalEntryPipeline.swift
//  MedJourney
//
//  Services/AI — Orchestrates everything that happens when a journal entry is saved.
//
//  Flow:
//   1. LocalExtractionService → extract tags on-device (respects existing fallback).
//   2. If on-device model is unavailable → LLMAnalysisService.generateDailyTags (fallback).
//   3. HealthSummaryManager → append entry + tags to health_summary.md (capped at 30).
//   4. Background task → refresh the "Daily Summary Context" section.
//
//  TODO: integrate with existing JournalEntry persistence (JournalEntryRepository) —
//  call `process(entry:)` after the entry is saved; this layer does not persist entries.
//

import Foundation

/// The result returned to the UI/view-model after a journal entry is processed.
struct ProcessedJournalResult {
    /// Final tags (on-device or cloud fallback).
    let tags: [HealthTag]
    /// True when the cloud LLM fallback was used because on-device was unavailable.
    let usedCloudFallback: Bool
    /// Estimated token size of the curated MD file after the update.
    let summaryTokenEstimate: Int
}

/// Coordinates local extraction + MD-file update for a saved journal entry.
final class JournalEntryPipeline {

    static let shared = JournalEntryPipeline()

    private let localExtraction: LocalExtractionService
    private let llm: LLMAnalysisService
    private let summaryManager: HealthSummaryManager

    init(
        localExtraction: LocalExtractionService = .shared,
        llm: LLMAnalysisService = .shared,
        summaryManager: HealthSummaryManager = .shared
    ) {
        self.localExtraction = localExtraction
        self.llm = llm
        self.summaryManager = summaryManager
    }

    /// Runs the full journal-save pipeline and returns the tags + summary stats.
    func process(entry: JournalEntry) async -> ProcessedJournalResult {
        let vitals = VitalsInput(
            bloodPressure: entry.bloodPressure,
            heartRate: entry.heartRate,
            temperature: entry.temperature,
            weight: entry.weight
        )

        // Step 1 — on-device extraction (preserves existing fallback logic internally).
        var tags = await localExtraction.extractTags(from: entry.content, vitals: vitals)
        var usedCloudFallback = false

        // Step 2/3 — cloud fallback ONLY when on-device symptom extraction is unavailable.
        // NOTE: preserving existing fallback logic — we mirror the on-device service's
        // availability decision rather than introducing a new condition.
        let symptomTagsPresent = tags.contains { $0.category == .symptom }
        if !localExtraction.isLocalModelAvailable && !symptomTagsPresent &&
            !entry.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if let cloudTags = try? await llm.generateDailyTags(journalText: entry.content) {
                tags += cloudTags
                usedCloudFallback = true
            }
        }

        // Step 3 — update the curated MD file with the entry + tags.
        await summaryManager.updateFromJournalEntry(entry, tags: tags)

        // Step 4 — refresh the Daily Summary Context off the critical path.
        // Capture only Sendable values (tags + date) — `entry` is a SwiftData @Model
        // and must not cross the task boundary.
        let entryDate = entry.createdAt
        let snapshotTags = tags
        Task.detached(priority: .background) { [summaryManager] in
            let snapshot = Self.buildSnapshot(from: snapshotTags, entryDate: entryDate)
            await summaryManager.updateDailySummaryContext(snapshot)
        }

        let estimate = await summaryManager.getSummaryTokenEstimate()
        return ProcessedJournalResult(tags: tags, usedCloudFallback: usedCloudFallback, summaryTokenEstimate: estimate)
    }

    /// Builds a tiny 1–2 sentence snapshot for the Daily Summary Context section.
    /// Kept fully local (no tokens) — it just phrases the latest tags.
    private static func buildSnapshot(from tags: [HealthTag], entryDate: Date) -> String {
        let labels = tags.prefix(4).map(\.label)
        if labels.isEmpty {
            return "User journaled today with no notable symptoms or vital alerts."
        }
        let hasAlert = tags.contains { $0.category == .vitalAlert }
        let lead = hasAlert ? "Recent entry flagged: " : "Recently noted: "
        return "\(lead)\(labels.joined(separator: ", ")). Logged on \(entryDate.formatted(date: .abbreviated, time: .omitted))."
    }
}
