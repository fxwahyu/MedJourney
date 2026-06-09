//
//  ChecklistHistoryStore.swift
//  MedJourney
//
//  Persistence — UserDefaults-backed daily checklist completion history
//
//  Stores per-day completion snapshots so the Insights screen can display
//  historical completion rates without requiring a SwiftData schema migration.
//
//  Written to by HomeTabView each time the checklist resets (once per day).
//  Read by InsightsViewModel to compute trend statistics.
//

import Foundation

/// A single day's checklist completion snapshot.
struct DailyChecklistRecord: Codable {
    let date: Date
    let total: Int
    let completed: Int

    var completionRate: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }
}

/// Lightweight UserDefaults store for daily checklist completion history.
///
/// Records are automatically capped at 90 days. Calling `recordToday`
/// overwrites any existing record for the current calendar day.
final class ChecklistHistoryStore {

    static let shared = ChecklistHistoryStore()
    private let key = "medjourney_checklist_history_v1"
    private let maxDays = 90

    private init() {}

    // MARK: - Write

    /// Records today's completion state. Replaces the existing record if today already has one.
    func recordToday(total: Int, completed: Int) {
        var history = load()
        history.removeAll { Calendar.current.isDateInToday($0.date) }
        history.append(DailyChecklistRecord(date: Date(), total: total, completed: completed))

        // Prune to maxDays
        let cutoff = Calendar.current.date(byAdding: .day, value: -maxDays, to: Date()) ?? Date()
        history = history
            .filter  { $0.date >= cutoff }
            .sorted  { $0.date < $1.date }

        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    // MARK: - Read

    /// Returns the average completion rate over the given number of past days.
    func averageRate(forPastDays days: Int = 30) -> Double? {
        let records = load()
        guard !records.isEmpty else { return nil }
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let relevant = records.filter { $0.date >= cutoff }
        guard !relevant.isEmpty else { return nil }
        return relevant.map(\.completionRate).reduce(0, +) / Double(relevant.count)
    }

    /// Returns all stored records, oldest first.
    func load() -> [DailyChecklistRecord] {
        guard
            let data    = UserDefaults.standard.data(forKey: key),
            let records = try? JSONDecoder().decode([DailyChecklistRecord].self, from: data)
        else { return [] }
        return records
    }
}
