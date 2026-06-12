//
//  JournalEntry.swift
//  MedJourney
//
//  Persistence Layer — SwiftData model for health journal entries
//

import Foundation
import SwiftData

/// A single health record: a mood journal, a medical checkup, or a medication log.
@Model
final class JournalEntry {

    // MARK: - Properties

    @Attribute(.unique)
    var id: UUID

    var title: String
    var content: String
    var entryTypeRaw: String

    /// Discomfort level on a 1-10 scale (nil if not applicable).
    var discomfortLevel: Int?

    /// Blood pressure reading, e.g. "120/80".
    var bloodPressure: String?

    /// Heart rate in BPM.
    var heartRate: Int?

    /// Body temperature in °C.
    var temperature: Double?

    /// Body weight in kg.
    var weight: Double?

    var createdAt: Date
    var updatedAt: Date

    /// Comma-separated AI-generated tags (nil = not yet generated).
    var aiTagsRaw: String?

    /// Structured AI markdown analysis (checkups only).
    var aiAnalysis: String?

    /// Uploaded document images, stored outside the SQLite DB.
    @Attribute(.externalStorage)
    var attachedImagesData: [Data]?

    // MARK: - Computed Properties

    var aiTags: [String] {
        get {
            aiTagsRaw?.split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty } ?? []
        }
        set {
            aiTagsRaw = newValue.joined(separator: ",")
        }
    }

    /// Type-safe access to the entry type.
    var entryType: EntryType {
        get { EntryType(rawValue: entryTypeRaw) ?? .journal }
        set { entryTypeRaw = newValue.rawValue }
    }

    // MARK: - Entry Type

    enum EntryType: String, Codable, CaseIterable, Identifiable {
        case journal
        case checkup
        case medication

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .journal: return "Journaling"
            case .checkup: return "Medical Analysis"
            case .medication: return "Medication"
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
        aiTagsRaw: String? = nil,
        aiAnalysis: String? = nil,
        attachedImagesData: [Data]? = nil,
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
        self.aiTagsRaw = aiTagsRaw
        self.aiAnalysis = aiAnalysis
        self.attachedImagesData = attachedImagesData
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
