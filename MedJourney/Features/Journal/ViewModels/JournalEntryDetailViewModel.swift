//
//  JournalEntryDetailViewModel.swift
//  MedJourney
//

import SwiftUI

/// Handles on-demand AI analysis for a saved entry shown in the detail sheet
/// (checkups saved before being analyzed).
@Observable
final class JournalEntryDetailViewModel {

    var isGeneratingTags = false

    private let tagService: AITagServiceProtocol

    init(tagService: AITagServiceProtocol = LLMTagService()) {
        self.tagService = tagService
    }

    /// Runs OCR on the entry's attached documents (if any) and generates tags +
    /// analysis, writing the result back onto the entry.
    func generateTags(for entry: JournalEntry) {
        guard !isGeneratingTags else { return }
        isGeneratingTags = true

        Task.detached(priority: .userInitiated) {
            var ocrText: String?
            if let imagesData = entry.attachedImagesData {
                let images = imagesData.compactMap { UIImage(data: $0) }
                ocrText = try? await DocumentScannerService().extractText(from: images)
            }
            guard let result = try? await self.tagService.generateTags(for: entry, ocrText: ocrText),
                  !result.tags.isEmpty else {
                await MainActor.run { self.isGeneratingTags = false }
                return
            }
            await MainActor.run {
                entry.aiTags = result.tags
                entry.aiAnalysis = result.analysis
                entry.updatedAt = Date()
                self.isGeneratingTags = false
            }
        }
    }
}
