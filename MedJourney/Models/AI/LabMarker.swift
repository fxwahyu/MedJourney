//
//  LabMarker.swift
//  MedJourney
//
//  Models/AI — A single lab/vital value parsed from a checkup analysis.
//
//  Feeds the "Lab Trends" and "Flagged Abnormals" tables in health_summary.md.
//

import Foundation

/// One measured marker from a checkup (e.g. Hemoglobin, Fasting Glucose, BP).
struct LabMarker: Identifiable, Codable, Hashable {

    let id: UUID

    /// Marker name, e.g. "Hemoglobin".
    let name: String

    /// Measured value as displayed, e.g. "11.2".
    let value: String

    /// Unit of measure, e.g. "g/dL" (empty if not applicable).
    let unit: String

    /// Reference / normal range string, e.g. "13.5–17.5".
    let normalRange: String

    /// True when the value falls outside `normalRange`.
    let isAbnormal: Bool

    /// Direction of change vs prior readings, when known.
    let trend: Trend

    init(
        id: UUID = UUID(),
        name: String,
        value: String,
        unit: String = "",
        normalRange: String,
        isAbnormal: Bool,
        trend: Trend = .stable
    ) {
        self.id = id
        self.name = name
        self.value = value
        self.unit = unit
        self.normalRange = normalRange
        self.isAbnormal = isAbnormal
        self.trend = trend
    }

    /// Status glyph used when rendering the marker into the MD table.
    var statusEmoji: String { isAbnormal ? "⚠️" : "✅" }

    /// Trend of a marker across successive checkups.
    enum Trend: String, Codable {
        case improving
        case stable
        case worsening
    }
}
