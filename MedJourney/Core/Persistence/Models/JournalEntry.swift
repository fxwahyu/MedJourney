//
//  JournalEntry.swift
//  MedJourney
//
//  Persistence Layer — SwiftData model for health journal entries
//

import Foundation
import SwiftData

/// Represents a single health journal entry stored locally via SwiftData.
///
/// Supports three entry types matching the MedJourney design:
/// - **symptom**: User describes how they feel + discomfort level
/// - **checkup**: Medical checkup data and lab results
/// - **medication**: Medication name, dosage, and timing
///
/// This model is registered in `SwiftDataContainer` and accessed
/// via `JournalEntryRepository`.
@Model
final class JournalEntry {

    // MARK: - Properties

    /// Unique identifier for the entry
    @Attribute(.unique)
    var id: UUID

    /// Short title summarizing the entry
    var title: String

    /// Full content / description of the entry
    var content: String

    /// The type of journal entry
    var entryTypeRaw: String

    /// Discomfort level on a 1-10 scale (nil if not applicable)
    var discomfortLevel: Int?

    /// Blood pressure reading (e.g., "120/80")
    var bloodPressure: String?

    /// Heart rate in BPM
    var heartRate: Int?

    /// Body temperature in Celsius
    var temperature: Double?

    /// Body weight in kilograms
    var weight: Double?

    /// When the entry was created
    var createdAt: Date

    /// When the entry was last modified
    var updatedAt: Date

    // MARK: - Computed Properties

    /// Type-safe access to the entry type
    var entryType: EntryType {
        get { EntryType(rawValue: entryTypeRaw) ?? .journal }
        set { entryTypeRaw = newValue.rawValue }
    }

    // MARK: - Entry Type

    /// The category of a journal entry.
    enum EntryType: String, Codable, CaseIterable, Identifiable {
        case journal = "journal"
        case checkup = "checkup"
        case medication = "medication"

        var id: String { rawValue }

        /// Display name for UI
        var displayName: String {
            switch self {
            case .journal: return "Journaling"
            case .checkup: return "Medical Analysis"
            case .medication: return "Medication"
            }
        }

        /// SF Symbol icon name
        var iconName: String {
            switch self {
            case .journal: return "heart.text.square"
            case .checkup: return "sparkles"
            case .medication: return "pills"
            }
        }

        /// Emoji prefix for display
        var emoji: String {
            switch self {
            case .journal: return "✍️"
            case .checkup: return "📋"
            case .medication: return "💊"
            }
        }
    }

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        title: String,
        content: String,
        entryType: EntryType = .journal,
        discomfortLevel: Int? = nil,
        bloodPressure: String? = nil,
        heartRate: Int? = nil,
        temperature: Double? = nil,
        weight: Double? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.entryTypeRaw = entryType.rawValue
        self.discomfortLevel = discomfortLevel
        self.bloodPressure = bloodPressure
        self.heartRate = heartRate
        self.temperature = temperature
        self.weight = weight
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
