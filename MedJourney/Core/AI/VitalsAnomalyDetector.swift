//
//  VitalsAnomalyDetector.swift
//  MedJourney
//

import Foundation

// MARK: - Anomaly Model

/// A flagged deviation from the user's personal vitals baseline.
struct VitalsAnomaly: Identifiable {
    let id = UUID()

    enum VitalType: String {
        case systolicBP  = "Systolic BP"
        case diastolicBP = "Diastolic BP"
        case heartRate   = "Heart Rate"
        case temperature = "Temperature"
        case weight      = "Weight"
    }

    let type: VitalType
    let currentValue: Double
    let personalMean: Double
    let personalStdDev: Double
    let deviationsFromMean: Double
    /// How many consecutive recent readings are in the same direction
    let consecutiveFlaggedReadings: Int

    var isAboveMean: Bool { currentValue > personalMean }

    var shortLabel: String { type.rawValue }

    /// User-facing warning suitable for the dashboard card.
    var message: String {
        let direction = isAboveMean ? "above" : "below"
        if consecutiveFlaggedReadings > 1 {
            return "Your \(type.rawValue.lowercased()) has been \(direction) your personal average for \(consecutiveFlaggedReadings) consecutive readings. Consider mentioning this to your doctor."
        }
        return "Your latest \(type.rawValue.lowercased()) reading is notably \(direction) your personal average."
    }
}

// MARK: - Detector

/// On-device vitals anomaly detection — pure Swift, no ML model.
///
/// Compares readings against the user's own rolling mean (not clinical ranges),
/// so the detector personalises to each individual's normal and catches relative
/// changes that generic thresholds would miss. Applies to systolic/diastolic BP,
/// heart rate, temperature, and weight.
enum VitalsAnomalyDetector {

    /// Minimum readings required before the detector activates.
    static let minimumDataPoints = 7

    /// Standard deviation multiplier — readings beyond this are flagged.
    static let deviationThreshold = 2.0

    // MARK: - Public

    /// Analyses journal entries and returns all flagged vitals anomalies.
    static func detect(from entries: [JournalEntry]) -> [VitalsAnomaly] {
        let sorted = entries
            .filter { $0.entryType == .journal }
            .sorted { $0.createdAt < $1.createdAt }

        var anomalies: [VitalsAnomaly] = []

        // Blood pressure — parse "120/80" into systolic + diastolic series
        let bpPairs = sorted.compactMap { e -> (date: Date, sys: Double, dia: Double)? in
            guard let raw = e.bloodPressure, let (s, d) = parseBP(raw) else { return nil }
            return (e.createdAt, Double(s), Double(d))
        }
        if let a = checkAnomaly(in: bpPairs.map { ($0.date, $0.sys) }, type: .systolicBP)  { anomalies.append(a) }
        if let a = checkAnomaly(in: bpPairs.map { ($0.date, $0.dia) }, type: .diastolicBP) { anomalies.append(a) }

        // Heart rate
        let hrSeries = sorted.compactMap { e -> (Date, Double)? in
            guard let hr = e.heartRate else { return nil }
            return (e.createdAt, Double(hr))
        }
        if let a = checkAnomaly(in: hrSeries, type: .heartRate) { anomalies.append(a) }

        // Temperature
        let tempSeries = sorted.compactMap { e -> (Date, Double)? in
            guard let t = e.temperature else { return nil }
            return (e.createdAt, t)
        }
        if let a = checkAnomaly(in: tempSeries, type: .temperature) { anomalies.append(a) }

        // Weight
        let weightSeries = sorted.compactMap { e -> (Date, Double)? in
            guard let w = e.weight else { return nil }
            return (e.createdAt, w)
        }
        if let a = checkAnomaly(in: weightSeries, type: .weight) { anomalies.append(a) }

        return anomalies
    }

    // MARK: - Private

    private static func checkAnomaly(
        in series: [(Date, Double)],
        type: VitalsAnomaly.VitalType
    ) -> VitalsAnomaly? {
        guard series.count >= minimumDataPoints else { return nil }

        let values = series.map { $0.1 }
        let mean   = values.reduce(0.0, +) / Double(values.count)
        let variance = values.map { pow($0 - mean, 2) }.reduce(0.0, +) / Double(values.count)
        let stdDev = sqrt(variance)

        guard stdDev > 0.001 else { return nil }      // perfectly stable vitals → skip
        guard let latest = series.last else { return nil }

        let deviations = abs(latest.1 - mean) / stdDev
        guard deviations >= deviationThreshold else { return nil }

        // Count consecutive recent readings trending in the same direction
        let isAbove = latest.1 > mean
        let consecutive = series.reversed().prefix(while: { isAbove ? $0.1 > mean : $0.1 < mean }).count

        return VitalsAnomaly(
            type: type,
            currentValue: latest.1,
            personalMean: mean,
            personalStdDev: stdDev,
            deviationsFromMean: deviations,
            consecutiveFlaggedReadings: consecutive
        )
    }

    /// Parses "120/80" → (systolic: 120, diastolic: 80). Returns nil on malformed input.
    private static func parseBP(_ raw: String) -> (Int, Int)? {
        let parts = raw.split(separator: "/")
        guard
            parts.count == 2,
            let sys = Int(parts[0].trimmingCharacters(in: .whitespaces)),
            let dia = Int(parts[1].trimmingCharacters(in: .whitespaces))
        else { return nil }
        return (sys, dia)
    }
}
