//
//  LocalExtractionService.swift
//  MedJourney
//
//  Services/AI — Layer 1 of the pipeline: on-device, zero-token tag extraction.
//
//  Uses Apple Foundation Models (via the existing FoundationModelsService) to pull
//  symptoms from free journal text, and derives vital-alert tags locally with no
//  model call at all. Falls back gracefully when Foundation Models is unavailable.
//
//  NOTE: preserving existing fallback logic — this service does NOT touch the
//  FoundationModels framework directly. It delegates to `FoundationModelsService.shared`,
//  which already owns all availability checks, the `GenerationError -1` skip-caching,
//  and the iOS-version gating. We must not change, override, or duplicate that behavior.
//

import Foundation

/// Lightweight vitals snapshot passed into local extraction so vital-alert tags
/// can be derived without any model call.
struct VitalsInput {
    var bloodPressure: String?   // "120/80"
    var heartRate: Int?          // bpm
    var temperature: Double?     // °C
    var weight: Double?          // kg

    init(bloodPressure: String? = nil, heartRate: Int? = nil, temperature: Double? = nil, weight: Double? = nil) {
        self.bloodPressure = bloodPressure
        self.heartRate = heartRate
        self.temperature = temperature
        self.weight = weight
    }
}

/// On-device extraction of structured `HealthTag`s from a journal entry.
final class LocalExtractionService {

    static let shared = LocalExtractionService()

    /// The existing on-device service. We reuse it verbatim to honor its fallback rules.
    private let foundationModels: FoundationModelsService

    init(foundationModels: FoundationModelsService = .shared) {
        self.foundationModels = foundationModels
    }

    /// Extracts symptom/vital-alert tags from free journal text plus optional vitals.
    ///
    /// - Symptom tags come from Apple Foundation Models when available.
    /// - Vital-alert tags are computed locally from `vitals` and always run.
    /// - Returns an empty symptom set (but still any vital alerts) when the on-device
    ///   model is unavailable — callers detect this and fall back to the cloud LLM.
    func extractTags(from journalText: String, vitals: VitalsInput?) async -> [HealthTag] {
        var tags: [HealthTag] = []

        // NOTE: preserving existing fallback logic — `isAvailable` already accounts for
        // Apple Intelligence availability AND confirmed model-asset download.
        if foundationModels.isAvailable {
            if let symptomLabels = await foundationModels.extractLiveTags(from: journalText) {
                tags += symptomLabels.map {
                    HealthTag(label: $0, category: .symptom, source: .local)
                }
            }
        }

        // Vital-alert tags are derived locally — no model, no tokens, always available.
        if let vitals { tags += vitalAlertTags(from: vitals) }

        return dedupe(tags)
    }

    /// True when the on-device model is currently usable. Callers use this to decide
    /// whether a cloud LLM fallback is required for symptom extraction.
    ///
    /// NOTE: preserving existing fallback logic — value comes straight from the
    /// existing service; do not reinterpret it.
    var isLocalModelAvailable: Bool {
        foundationModels.isAvailable
    }

    // MARK: - Local vital-alert rules

    /// Derives vital-alert tags from raw vitals using the same thresholds the existing
    /// Gemini prompt documents (kept observational, never diagnostic).
    private func vitalAlertTags(from vitals: VitalsInput) -> [HealthTag] {
        var alerts: [HealthTag] = []

        if let bp = vitals.bloodPressure {
            let parts = bp.split(separator: "/").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            if parts.count == 2 {
                let (sys, dia) = (parts[0], parts[1])
                if sys > 140 || dia > 90 { alerts.append(.init(label: "elevated BP", category: .vitalAlert, source: .local)) }
                else if sys < 90 { alerts.append(.init(label: "low BP reading", category: .vitalAlert, source: .local)) }
            }
        }
        if let hr = vitals.heartRate {
            if hr > 100 { alerts.append(.init(label: "elevated heart rate", category: .vitalAlert, source: .local)) }
            else if hr < 60 { alerts.append(.init(label: "low heart rate", category: .vitalAlert, source: .local)) }
        }
        if let temp = vitals.temperature {
            if temp > 37.5 { alerts.append(.init(label: "fever", category: .vitalAlert, source: .local)) }
            else if temp < 36 { alerts.append(.init(label: "low temperature", category: .vitalAlert, source: .local)) }
        }
        return alerts
    }

    /// Removes duplicate labels (case-insensitive), keeping first occurrence.
    private func dedupe(_ tags: [HealthTag]) -> [HealthTag] {
        var seen = Set<String>()
        return tags.filter { seen.insert($0.label.lowercased()).inserted }
    }
}
