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
/// `JournalEntryView` depends only on this ViewModel — it contains
/// no logic of its own, keeping the view purely declarative.
@Observable
final class JournalEntryViewModel {

    // MARK: - Entry State

    var entryType: JournalEntry.EntryType = .journal
    var entryContent: String = ""

    // MARK: - Journal Mood State

    var selectedMood: JournalMood? = nil
    var painLevel: Double = 0

    // MARK: - Medication State

    var medicationName: String = ""
    var medicationNotes: String = ""

    // MARK: - Medical Analysis State

    var selectedPhotoItems: [PhotosPickerItem] = [] {
        didSet { loadSelectedImages(from: selectedPhotoItems) }
    }
    var uploadedImages: [UIImage] = []
    var showAIDisclaimer: Bool = false

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

    // MARK: - Actions

    /// Selects a mood and resets pain level if Fit is chosen.
    func selectMood(_ mood: JournalMood) {
        withAnimation(.easeInOut(duration: 0.18)) {
            selectedMood = mood
            if !mood.showsPainSlider { painLevel = 0 }
        }
    }

    /// Removes an uploaded image by index.
    func removeImage(at index: Int) {
        guard index < uploadedImages.count else { return }
        withAnimation { uploadedImages.remove(at: index) }
    }

    /// Saves the entry to the SwiftData context and dismisses.
    func saveEntry(context: ModelContext, dismiss: DismissAction) {
        let autoTitle: String = {
            switch entryType {
            case .journal:
                return selectedMood.map { "\($0.rawValue) day" } ?? "Journal Entry"
            case .checkup:
                return "Medical Checkup"
            case .medication:
                return medicationName.isEmpty ? "Medication Log" : medicationName
            }
        }()

        let discomfortValue: Int? = selectedMood?.showsPainSlider == true
            ? Int(painLevel / 10)
            : nil

        let content: String = entryType == .medication ? medicationNotes : entryContent

        let entry = JournalEntry(
            title: autoTitle,
            content: content,
            entryType: entryType,
            discomfortLevel: discomfortValue
        )
        context.insert(entry)
        dismiss()
    }

    // MARK: - Private

    private func loadSelectedImages(from items: [PhotosPickerItem]) {
        Task {
            var images: [UIImage] = []
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    images.append(image)
                }
            }
            await MainActor.run {
                self.uploadedImages = images
            }
        }
    }
}
