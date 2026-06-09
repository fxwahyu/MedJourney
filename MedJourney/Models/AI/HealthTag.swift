//
//  HealthTag.swift
//  MedJourney
//
//  Models/AI — A single health observation tag produced by the AI pipeline.
//
//  Tags come from two sources:
//  - `.local`  → extracted on-device via Apple Foundation Models (zero tokens)
//  - `.llm`    → extracted by the cloud LLM (fallback only)
//
//  Tags are observational, never diagnostic (see existing GeminiTagService safety rules).
//

import Foundation

/// A structured, categorized health tag with provenance.
struct HealthTag: Identifiable, Codable, Hashable {

    /// Stable identifier for diffing / SwiftUI lists.
    let id: UUID

    /// Short observational label, e.g. "headache", "elevated BP", "fatigue".
    let label: String

    /// What kind of signal this tag represents.
    let category: Category

    /// When the tag was generated.
    let date: Date

    /// Where the tag came from — local on-device model or cloud LLM.
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

    /// The semantic category of a tag.
    enum Category: String, Codable, CaseIterable {
        case symptom        // e.g. "headache", "nausea"
        case condition      // an ongoing flagged pattern (never a diagnosis)
        case vitalAlert     // e.g. "elevated BP", "fever"
        case medication     // e.g. "ibuprofen"
    }

    /// Provenance of the tag — used to decide whether a cloud fallback already ran.
    enum Source: String, Codable {
        case local          // Apple Foundation Models (on-device)
        case llm            // Cloud LLM fallback
    }
}

// MARK: - Conversion from plain labels

extension HealthTag {

    /// Builds `HealthTag`s from plain label strings — e.g. the comma-separated tags
    /// already produced by `GeminiTagService` / `FoundationModelsService`.
    ///
    /// Used to feed the curated `health_summary.md` knowledge base from results the
    /// live AI flows already generated, instead of running a second extraction pass.
    /// Categorizes a label as `.vitalAlert` when it mentions common vitals keywords
    /// (mirrors the observational vocabulary in `GeminiTagService`'s prompt rules);
    /// everything else is treated as a `.symptom` observation.
    static func from(labels: [String], source: Source, date: Date = Date()) -> [HealthTag] {
        let vitalKeywords = ["bp", "blood pressure", "heart rate", "pulse", "fever", "temperature"]
        return labels.map { label in
            let isVital = vitalKeywords.contains { label.lowercased().contains($0) }
            return HealthTag(label: label, category: isVital ? .vitalAlert : .symptom, date: date, source: source)
        }
    }
}
