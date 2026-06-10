//
//  JournalEntryViewModel.swift
//  MedJourney
//
//  Feature: Journal — ViewModel for new entry creation
//

import SwiftUI
import SwiftData
import PhotosUI

/// All state and business logic for creating a new journal entry.
///
/// AI pipeline for journal entries:
///   1. On-device Foundation Models pre-processing (urgency detection + symptom extraction)
///   2. If urgent → expose `showUrgencyAlert`, hold the save
///   3. If clear (or urgency acknowledged) → save, forward cleaned content to Gemini for tags
///
/// Raw user text never reaches Gemini directly — the cleaned output from
/// Foundation Models acts as the privacy filter between device and cloud.
@Observable
final class JournalEntryViewModel {

    // MARK: - Dependencies

    private let tagService: AITagServiceProtocol

    init(tagService: AITagServiceProtocol = LLMTagService()) {
        self.tagService = tagService
    }

    // MARK: - Entry State

    var entryType: JournalEntry.EntryType = .journal
    var entryContent: String = ""

    // MARK: - Journal Mood State

    var selectedMood: JournalMood? = nil
    var painLevel: Double = 0

    // MARK: - Medication State

    var medicationName: String = ""
    var medicationNotes: String = ""

    // MARK: - Quick Vitals State

    var bloodPressure: String = ""
    var heartRate: String = ""
    var temperature: String = ""
    var weight: String = ""

    // MARK: - Medical Analysis State

    var selectedPhotoItems: [PhotosPickerItem] = [] {
        didSet { loadSelectedImages(from: selectedPhotoItems) }
    }
    var uploadedImages: [UIImage] = []
    var showAIDisclaimer: Bool = false

    // MARK: - AI Analysis State

    var isAnalyzingAI: Bool = false
    var aiTags: [String]?
    var aiAnalysis: String?

    // MARK: - Foundation Models: Pre-processing State

    /// True while on-device urgency + extraction analysis is running
    var isPreProcessing: Bool = false

    /// Triggers the in-app urgency alert when red-flag language is detected
    var showUrgencyAlert: Bool = false

    /// The specific red-flag phrases that triggered the alert
    var urgentKeywords: [String] = []

    /// Set after the user acknowledges the alert — prevents re-running pre-processing
    var urgencyAcknowledged: Bool = false

    /// Stores the last pre-processing output; `cleanedContent` feeds Gemini
    private var lastPreProcessingResult: JournalPreProcessingResult?

    // MARK: - Foundation Models: Journal Opening Prompt

    /// Contextual warm opening question generated on-device before the user starts typing
    var journalOpeningPrompt: String? = nil
    var isLoadingPrompt: Bool = false

    // MARK: - Foundation Models: Live Tag Generation

    /// Tags extracted in real-time as the user types — purely on-device, zero cloud calls.
    var liveTagSuggestions: [String] = []

    /// True while Foundation Models is generating tags from the current text.
    var isGeneratingLiveTags: Bool = false

    /// Cancels the previous debounce when the user types again before the delay fires.
    private var liveTagDebounceTask: Task<Void, Never>? = nil

    // MARK: - Computed: Pain Level Display

    var painLevelLabel: String {
        switch painLevel {
        case 0..<20: return "Mild"
        case 20..<50: return "Moderate"
        case 50..<80: return "Significant"
        default: return "Severe"
        }
    }

    var painLevelColor: Color {
        switch painLevel {
        case 0..<20: return AppColors.brandDark
        case 20..<50: return AppColors.accentOrange
        case 50..<80: return AppColors.error.opacity(0.8)
        default: return AppColors.error
        }
    }

    // MARK: - Mood

    func selectMood(_ mood: JournalMood) {
        withAnimation(.easeInOut(duration: 0.18)) {
            selectedMood = mood
            if !mood.showsPainSlider { painLevel = 0 }
        }
    }

    func removeImage(at index: Int) {
        guard index < uploadedImages.count else { return }
        withAnimation { uploadedImages.remove(at: index) }
    }

    // MARK: - Journal Opening Prompt

    /// Reads the AI daily briefing already generated on the Home screen.
    /// Reuses `AIBriefingStore.shared.message` — no extra generation or API call.
    func loadJournalPrompt(
        entries: [JournalEntry],
        checklistItems: [ChecklistItem],
        medicines: [Medicine]
    ) {
        // If the home briefing is already ready, use it immediately
        if let existing = AIBriefingStore.shared.message {
            journalOpeningPrompt = existing
            isLoadingPrompt = false
            return
        }
        // Still loading on the Home screen — show the spinner and wait
        isLoadingPrompt = true
        Task { @MainActor in
            // Poll briefly (max ~3 s) in case Home briefing arrives shortly after
            for _ in 0..<6 {
                try? await Task.sleep(for: .milliseconds(500))
                if let msg = AIBriefingStore.shared.message {
                    self.journalOpeningPrompt = msg
                    self.isLoadingPrompt = false
                    return
                }
            }
            // Home briefing never arrived — show nothing rather than duplicate a call
            self.isLoadingPrompt = false
        }
    }

    private func buildPromptContext(
        entries: [JournalEntry],
        checklistItems: [ChecklistItem],
        medicines: [Medicine]
    ) -> JournalPromptContext {
        var ctx = JournalPromptContext()

        let journalEntries = entries.filter { $0.entryType == .journal }

        // Days since last entry
        if let last = journalEntries.first {
            ctx.daysSinceLastEntry = Calendar.current.dateComponents([.day], from: last.createdAt, to: Date()).day ?? 0
        }

        // Recent tags from the last 5 entries
        ctx.recentTags = Array(journalEntries.prefix(5).flatMap { $0.aiTags }.prefix(8))

        // Most recent vitals
        if let recent = journalEntries.first {
            ctx.recentVitalsBP   = recent.bloodPressure
            ctx.recentVitalsHR   = recent.heartRate
            ctx.recentVitalsTemp = recent.temperature
        }

        // Vitals anomaly flag from on-device detector
        let anomalies = VitalsAnomalyDetector.detect(from: Array(entries.prefix(50)))
        ctx.hasVitalsAnomaly = !anomalies.isEmpty

        // Yesterday's checklist from history store
        if let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) {
            let record = ChecklistHistoryStore.shared.load()
                .first { Calendar.current.isDate($0.date, inSameDayAs: yesterday) }
            ctx.yesterdayChecklistCompletion = record?.completionRate
        }

        // Medications started in the last 7 days
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        ctx.recentMedicationNames = medicines
            .filter { $0.startDate >= sevenDaysAgo }
            .map    { $0.name }

        return ctx
    }

    // MARK: - Foundation Models: Live Tag Generation

    /// Called on every `entryContent` change. Cancels any pending generation, waits 1.5 s
    /// after the user stops typing, then calls Foundation Models for tag extraction.
    ///
    /// On-device only — never reaches Gemini or any cloud service.
    func scheduleLiveTagGeneration() {
        liveTagDebounceTask?.cancel()

        let trimmed = entryContent.trimmingCharacters(in: .whitespacesAndNewlines)

        // Clear immediately when text is wiped
        guard entryType == .journal, trimmed.count >= 20 else {
            if trimmed.isEmpty {
                withAnimation(.easeOut(duration: 0.2)) { liveTagSuggestions = [] }
                isGeneratingLiveTags = false
            }
            return
        }

        // Live tags are on-device only — no Gemini call during typing.
        // When the entry is saved, Gemini generates the final persistent tags anyway.
        guard FoundationModelsService.shared.isAvailable else { return }

        liveTagDebounceTask = Task { @MainActor in
            // Wait for the user to pause before hitting the model
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }

            isGeneratingLiveTags = true
            let snapshot = self.entryContent
            let tags = await FoundationModelsService.shared.extractLiveTags(from: snapshot)

            guard !Task.isCancelled else {
                isGeneratingLiveTags = false
                return
            }

            withAnimation(.spring(duration: 0.35)) {
                self.liveTagSuggestions = tags ?? []
                self.isGeneratingLiveTags = false
            }
        }
    }

    // MARK: - Medical Analysis (Checkup)

    /// Triggers OCR → Gemini analysis on uploaded medical documents.
    func analyzeWithAI() {
        guard !uploadedImages.isEmpty, !isAnalyzingAI else { return }
        isAnalyzingAI = true
        showAIDisclaimer = false

        Task {
            let scanner = DocumentScannerService()
            let ocrText = try? await scanner.extractText(from: uploadedImages)

            let tempEntry = JournalEntry(
                title: "Medical Checkup",
                content: entryContent,
                entryType: .checkup,
                bloodPressure: bloodPressure.isEmpty ? nil : bloodPressure,
                heartRate: Int(heartRate),
                temperature: Double(temperature),
                weight: Double(weight)
            )

            do {
                let result = try await tagService.generateTags(for: tempEntry, ocrText: ocrText)
                await MainActor.run {
                    withAnimation(.spring) {
                        self.aiTags     = result.tags
                        self.aiAnalysis = result.analysis
                        self.isAnalyzingAI = false
                    }
                }
            } catch {
                await MainActor.run { self.isAnalyzingAI = false }
            }
        }
    }

    // MARK: - Save Entry

    /// Saves the journal entry with on-device Foundation Models pre-processing.
    ///
    /// Flow:
    ///   1. Run Foundation Models on-device (urgency detection + extraction)
    ///   2. If urgent → set `showUrgencyAlert = true`, hold save until acknowledged
    ///   3. If clear → save immediately, forward cleaned text to Gemini in background
    func saveEntry(context: ModelContext, dismiss: DismissAction) {
        guard !isPreProcessing else { return }

        // Only pre-process journal entries with non-empty text that haven't been checked yet
        let needsCheck = entryType == .journal
            && !entryContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !urgencyAcknowledged

        guard needsCheck else {
            let cleaned = lastPreProcessingResult?.cleanedContent ?? entryContent
            performSave(context: context, dismiss: dismiss, cleanedContent: cleaned)
            return
        }

        isPreProcessing = true

        Task { @MainActor in
            // On-device privacy layer — processes text before any cloud call
            let result = await FoundationModelsService.shared.preProcessJournalEntry(self.entryContent)
            self.lastPreProcessingResult = result
            self.isPreProcessing = false

            if result.isUrgent {
                // Show the urgency alert — save is held until user responds
                self.urgentKeywords    = result.urgentKeywords
                self.showUrgencyAlert  = true
            } else {
                self.performSave(context: context, dismiss: dismiss, cleanedContent: result.cleanedContent)
            }
        }
    }

    /// Called when user taps "Save Anyway" on the urgency alert.
    func acknowledgeUrgencyAndSave(context: ModelContext, dismiss: DismissAction) {
        urgencyAcknowledged = true
        let cleaned = lastPreProcessingResult?.cleanedContent ?? entryContent
        performSave(context: context, dismiss: dismiss, cleanedContent: cleaned)
    }

    // MARK: - Private Save

    private func performSave(context: ModelContext, dismiss: DismissAction, cleanedContent: String) {
        let autoTitle: String = {
            switch entryType {
            case .journal:    return selectedMood?.rawValue ?? "Journal Entry"
            case .checkup:    return "Medical Checkup"
            case .medication: return medicationName.isEmpty ? "Medication Log" : medicationName
            }
        }()

        let discomfortValue: Int? = selectedMood?.showsPainSlider == true ? Int(painLevel / 10) : nil
        let content    = entryType == .medication ? medicationNotes : entryContent
        let imageData  = uploadedImages.compactMap { $0.jpegData(compressionQuality: 0.8) }

        let entry = JournalEntry(
            title: autoTitle,
            content: content,
            entryType: entryType,
            discomfortLevel: discomfortValue,
            bloodPressure: bloodPressure.isEmpty ? nil : bloodPressure,
            heartRate: Int(heartRate),
            temperature: Double(temperature),
            weight: Double(weight),
            aiTagsRaw: aiTags?.joined(separator: ","),
            aiAnalysis: aiAnalysis,
            attachedImagesData: imageData.isEmpty ? nil : imageData
        )
        context.insert(entry)
        dismiss()

        // Checkups created here already carry AI results from `analyzeWithAI()` —
        // feed the curated health_summary.md knowledge base from that existing
        // output (no second cloud analysis pass; see HealthSummaryManager).
        if entry.entryType == .checkup, entry.aiTagsRaw != nil || entry.aiAnalysis != nil {
            let checkupTags     = entry.aiTags
            let checkupAnalysis = entry.aiAnalysis
            let checkupDate     = entry.createdAt
            Task.detached(priority: .background) {
                await HealthSummaryManager.shared.updateFromExistingCheckupResult(
                    tags: checkupTags, analysisMarkdown: checkupAnalysis, date: checkupDate
                )
            }
        }

        guard entry.entryType != .medication, entry.aiTagsRaw == nil else { return }

        // Background Gemini tag generation — uses Foundation Models cleaned content
        // so the cloud prompt receives structured, noise-free medical data
        let geminiContent = cleanedContent.isEmpty ? content : cleanedContent
        Task.detached(priority: .background) {
            let promptEntry = JournalEntry(
                title: entry.title,
                content: geminiContent,
                entryType: entry.entryType,
                discomfortLevel: entry.discomfortLevel,
                bloodPressure: entry.bloodPressure,
                heartRate: entry.heartRate,
                temperature: entry.temperature,
                weight: entry.weight
            )
            guard
                let result = try? await self.tagService.generateTags(for: promptEntry, ocrText: nil),
                !result.tags.isEmpty
            else { return }
            await MainActor.run {
                entry.aiTags    = result.tags
                entry.updatedAt = Date()
            }

            // Feed the curated health_summary.md knowledge base from the tags we
            // already generated above — this is the ONLY place journal entries
            // touch the MD file, keeping token usage to the existing single call.
            let healthTags = HealthTag.from(labels: result.tags, source: .llm, date: entry.createdAt)
            await HealthSummaryManager.shared.updateFromJournalEntry(entry, tags: healthTags)

            let labels = Array(result.tags.prefix(4))
            let snapshot = labels.isEmpty
                ? "User journaled today with no notable symptoms or vital alerts."
                : "Recently noted: \(labels.joined(separator: ", ")). Logged on \(entry.createdAt.formatted(date: .abbreviated, time: .omitted))."
            await HealthSummaryManager.shared.updateDailySummaryContext(snapshot)
        }
    }

    // MARK: - Private

    private func loadSelectedImages(from items: [PhotosPickerItem]) {
        Task {
            var images: [UIImage] = []
            for item in items {
                if let data  = try? await item.loadTransferable(type: Data.self),
                   let image = ImageDownsampler.downsampled(from: data) {
                    images.append(image)
                }
            }
            await MainActor.run { self.uploadedImages = images }
        }
    }
}
