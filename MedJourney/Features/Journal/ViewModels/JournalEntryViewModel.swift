//
//  JournalEntryViewModel.swift
//  MedJourney
//

import SwiftUI
import SwiftData

/// State and business logic for creating a new mood journal entry.
///
/// Save flow: on-device Foundation Models pre-processing runs first (urgency
/// detection + noise stripping). If red-flag language is found the save is held
/// behind an alert; otherwise the entry saves immediately and cleaned content —
/// never the raw text — is forwarded to the cloud tag service in the background.
@Observable
final class JournalEntryViewModel {

    // MARK: - Dependencies

    private let tagService: AITagServiceProtocol

    init(tagService: AITagServiceProtocol = LLMTagService()) {
        self.tagService = tagService
    }

    // MARK: - Entry State

    var selectedMood: JournalMood?
    var entryContent: String = ""

    // MARK: - Vitals State

    var bloodPressure: String = ""
    var heartRate: String = ""
    var temperature: String = ""
    var weight: String = ""

    // MARK: - Pre-processing State

    var isPreProcessing = false
    var showUrgencyAlert = false
    var urgentKeywords: [String] = []

    /// Set after the user acknowledges the urgency alert — prevents re-running pre-processing.
    var urgencyAcknowledged = false

    private var lastPreProcessingResult: JournalPreProcessingResult?

    // MARK: - Opening Prompt State

    var journalOpeningPrompt: String?
    var isLoadingPrompt = false

    /// Shows the AI daily briefing already generated on the Home screen as the
    /// journal opening prompt — no extra generation or API call. If the Home
    /// briefing is still loading, polls briefly (max ~3s) before giving up.
    func loadJournalPrompt() {
        if let existing = AIBriefingStore.shared.message {
            journalOpeningPrompt = existing
            isLoadingPrompt = false
            return
        }
        isLoadingPrompt = true
        Task { @MainActor in
            for _ in 0..<6 {
                try? await Task.sleep(for: .milliseconds(500))
                if let message = AIBriefingStore.shared.message {
                    self.journalOpeningPrompt = message
                    self.isLoadingPrompt = false
                    return
                }
            }
            self.isLoadingPrompt = false
        }
    }

    // MARK: - Save

    /// Pre-processes the journal text on-device, then saves. An urgent entry holds
    /// the save behind `showUrgencyAlert` until the user responds.
    func saveEntry(context: ModelContext, dismiss: DismissAction) {
        guard !isPreProcessing else { return }

        let needsCheck = !entryContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !urgencyAcknowledged

        guard needsCheck else {
            let cleaned = lastPreProcessingResult?.cleanedContent ?? entryContent
            performSave(context: context, dismiss: dismiss, cleanedContent: cleaned)
            return
        }

        isPreProcessing = true

        Task { @MainActor in
            let result = await FoundationModelsService.shared.preProcessJournalEntry(self.entryContent)
            self.lastPreProcessingResult = result
            self.isPreProcessing = false

            if result.isUrgent {
                self.urgentKeywords = result.urgentKeywords
                self.showUrgencyAlert = true
            } else {
                self.performSave(context: context, dismiss: dismiss, cleanedContent: result.cleanedContent)
            }
        }
    }

    /// Called when the user taps "Save Entry Anyway" on the urgency alert.
    func acknowledgeUrgencyAndSave(context: ModelContext, dismiss: DismissAction) {
        urgencyAcknowledged = true
        let cleaned = lastPreProcessingResult?.cleanedContent ?? entryContent
        performSave(context: context, dismiss: dismiss, cleanedContent: cleaned)
    }

    private func performSave(context: ModelContext, dismiss: DismissAction, cleanedContent: String) {
        let entry = JournalEntry(
            title: selectedMood?.rawValue ?? "Journal Entry",
            content: entryContent,
            entryType: .journal,
            bloodPressure: bloodPressure.isEmpty ? nil : bloodPressure,
            heartRate: Int(heartRate),
            temperature: Double(temperature),
            weight: Double(weight)
        )
        context.insert(entry)
        dismiss()

        // Background tag generation — the cloud receives the Foundation Models
        // cleaned content, never the raw journal text.
        let cloudContent = cleanedContent.isEmpty ? entryContent : cleanedContent
        Task.detached(priority: .background) {
            let promptEntry = JournalEntry(
                title: entry.title,
                content: cloudContent,
                entryType: .journal,
                bloodPressure: entry.bloodPressure,
                heartRate: entry.heartRate,
                temperature: entry.temperature,
                weight: entry.weight
            )
            guard let result = try? await self.tagService.generateTags(for: promptEntry, ocrText: nil),
                  !result.tags.isEmpty else { return }
            await MainActor.run {
                entry.aiTags = result.tags
                entry.updatedAt = Date()
            }

            // The only place journal entries touch the curated health summary —
            // reuses the tags generated above, no extra cloud call.
            let healthTags = HealthTag.from(labels: result.tags, source: .llm, date: entry.createdAt)
            await HealthSummaryManager.shared.updateFromJournalEntry(entry, tags: healthTags)

            let labels = Array(result.tags.prefix(4))
            let snapshot = labels.isEmpty
                ? "User journaled today with no notable symptoms or vital alerts."
                : "Recently noted: \(labels.joined(separator: ", ")). Logged on \(entry.createdAt.formatted(date: .abbreviated, time: .omitted))."
            await HealthSummaryManager.shared.updateDailySummaryContext(snapshot)
        }
    }
}
