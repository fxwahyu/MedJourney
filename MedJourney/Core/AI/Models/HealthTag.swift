//
//  HealthTag.swift
//  MedJourney
//

import Foundation

/// A single observational (never diagnostic) health tag with provenance.
struct HealthTag: Identifiable, Codable, Hashable {

    let id: UUID
    let label: String
    let category: Category
    let date: Date
    let source: Source

    init(
        id: UUID = UUID(),
        label: String,
        category: Category,
        date: Date = Date(),
        source: Source
    ) {
        self.id = id
        self.label = label
        self.category = category
        self.date = date
        self.source = source
    }

    enum Category: String, Codable {
        case symptom
        case vitalAlert
    }

    /// Where the tag came from — on-device Foundation Models or the cloud LLM.
    enum Source: String, Codable {
        case local
        case llm
    }
}

extension HealthTag {

    /// Builds `HealthTag`s from the plain label strings the tag services produce.
    /// Labels mentioning vitals keywords become `.vitalAlert`; everything else `.symptom`.
    static func from(labels: [String], source: Source, date: Date = Date()) -> [HealthTag] {
        let vitalKeywords = ["bp", "blood pressure", "heart rate", "pulse", "fever", "temperature"]
        return labels.map { label in
            let isVital = vitalKeywords.contains { label.lowercased().contains($0) }
            return HealthTag(label: label, category: isVital ? .vitalAlert : .symptom, date: date, source: source)
        }
    }
}
