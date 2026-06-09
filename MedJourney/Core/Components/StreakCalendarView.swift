//
//  StreakCalendarView.swift
//  MedJourney
//
//  Components — Monthly calendar grid showing entry mood per day
//

import SwiftUI
import SwiftData

/// A compact monthly calendar grid embedded inside the streak glassmorphic card.
///
/// Each day cell is:
/// - **Gray** — no entry that day
/// - **Colored** — colored based on the mood logged that day
/// - **Today** — highlighted with a white border ring
/// - **Tappable** — tapping a day with an entry calls `onEntryTapped`
///
/// Usage:
/// ```swift
/// StreakCalendarView(entries: entries) { entry in
///     selectedEntry = entry
/// }
/// ```
struct StreakCalendarView: View {

    let entries: [JournalEntry]
    var onEntryTapped: ((JournalEntry) -> Void)? = nil

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    private let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]

    // MARK: - Computed

    private var today: Date { Date() }

    private var firstOfMonth: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: today))!
    }

    private var daysInMonth: Int {
        calendar.range(of: .day, in: .month, for: today)!.count
    }

    /// Weekday offset so Monday = column 0
    private var startOffset: Int {
        let weekday = calendar.component(.weekday, from: firstOfMonth)
        return (weekday + 5) % 7
    }

    /// Maps day number → (color, first matching JournalEntry)
    private var entryByDay: [Int: (Color, JournalEntry)] {
        var result: [Int: (Color, JournalEntry)] = [:]
        for entry in entries {
            guard calendar.isDate(entry.createdAt, equalTo: today, toGranularity: .month) else { continue }
            let day = calendar.component(.day, from: entry.createdAt)
            if result[day] == nil {
                result[day] = (colorForEntry(entry), entry)
            }
        }
        return result
    }

    private func colorForEntry(_ entry: JournalEntry) -> Color {
        if let level = entry.discomfortLevel {
            switch level {
            case 0...2: return AppColors.brand.opacity(0.85)
            case 3...5: return AppColors.accentOrange.opacity(0.85)
            default:    return AppColors.error.opacity(0.75)
            }
        }
        return AppColors.brandSoft.opacity(0.85)
    }

    private var todayNumber: Int {
        calendar.component(.day, from: today)
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 6) {
            // Day-of-week header
            HStack(spacing: 0) {
                ForEach(Array(dayLabels.enumerated()), id: \.offset) { _, label in
                    Text(label)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(maxWidth: .infinity)
                }
            }

            // Day grid
            LazyVGrid(columns: columns, spacing: 4) {
                // Leading empty cells to align first day
                ForEach(0..<startOffset, id: \.self) { _ in
                    Color.clear.frame(height: 22)
                }

                ForEach(1...daysInMonth, id: \.self) { day in
                    dayCell(day)
                }
            }
        }
    }

    // MARK: - Day Cell

    @ViewBuilder
    private func dayCell(_ day: Int) -> some View {
        let isToday = day == todayNumber
        let isFuture = day > todayNumber
        let entryInfo = entryByDay[day]
        let hasEntry = entryInfo != nil
        let cellColor = entryInfo?.0

        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(cellBackground(color: cellColor, isFuture: isFuture))
                .frame(height: 22)
                .overlay {
                    if isToday {
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.white.opacity(0.9), lineWidth: 1.5)
                    }
                }

            Text("\(day)")
                .font(.system(size: 9, weight: isToday ? .bold : .regular))
                .foregroundStyle(cellTextColor(hasEntry: hasEntry, isFuture: isFuture, isToday: isToday))
        }
        // Only intercept taps on days that have an entry
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isFuture, let entry = entryInfo?.1 else { return }
            onEntryTapped?(entry)
        }
        // Visual feedback that a day is tappable
        .overlay {
            if hasEntry && !isFuture {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
            }
        }
    }

    private func cellBackground(color: Color?, isFuture: Bool) -> Color {
        if isFuture { return .clear }
        return color ?? Color.white.opacity(0.12)
    }

    private func cellTextColor(hasEntry: Bool, isFuture: Bool, isToday: Bool) -> Color {
        if isFuture { return .white.opacity(0.2) }
        if hasEntry { return .white }
        return isToday ? .white : .white.opacity(0.5)
    }
}

#Preview {
    ZStack {
        AppGradients.header.ignoresSafeArea()
        StreakCalendarView(entries: []) { _ in }
            .padding()
    }
}
