import SwiftUI

struct MedicineScheduleCard: View {
    let medicines: [Medicine]

    private struct ScheduleEntry: Identifiable {
        let id = UUID()
        let time: String
        let medicineNames: [String]
        let isPast: Bool
        let isNext: Bool
    }

    private var schedule: [ScheduleEntry] {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let currentTime = formatter.string(from: Date())

        var byTime: [String: [String]] = [:]
        for medicine in medicines {
            for t in Set(medicine.notificationTimes) {
                byTime[t, default: []].append(medicine.name)
            }
        }

        let sortedTimes = byTime.keys.sorted()
        let nextIndex   = sortedTimes.firstIndex(where: { $0 >= currentTime })

        return sortedTimes.enumerated().map { i, time in
            ScheduleEntry(
                time: time,
                medicineNames: (byTime[time] ?? []).sorted(),
                isPast: time < currentTime,
                isNext: i == nextIndex
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            headerRow
            Divider().foregroundStyle(AppColors.border)
            timelineList
        }
        .padding(AppSpacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .appShadow(.card)
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Medicine schedule")
                    .appFont(.bodySemibold)
                    .foregroundStyle(AppColors.textPrimary)
                Text(nextDoseText)
                    .appFont(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
            Spacer()
            Image(systemName: "pills.fill")
                .font(.system(size: 24))
                .foregroundStyle(AppColors.indigo.opacity(0.5))
        }
    }

    private var nextDoseText: String {
        if let next = schedule.first(where: { !$0.isPast }) {
            let count = next.medicineNames.count
            return count > 1
                ? "\(count) doses at \(next.time)"
                : "Next dose at \(next.time)"
        }
        return "All doses taken today"
    }

    // MARK: - Timeline

    private var timelineList: some View {
        VStack(spacing: 0) {
            ForEach(Array(schedule.prefix(5).enumerated()), id: \.element.id) { i, entry in
                timelineRow(entry: entry, isLast: i == min(schedule.count, 5) - 1)
            }
        }
    }

    private func timelineRow(entry: ScheduleEntry, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            Text(entry.time)
                .appFont(.mono)
                .foregroundStyle(entry.isPast ? AppColors.textTertiary : AppColors.textPrimary)
                .frame(width: 46, alignment: .leading)
                .padding(.top, 1)

            VStack(spacing: 0) {
                Circle()
                    .fill(entry.isPast ? AppColors.indigo.opacity(0.35) : AppColors.indigo)
                    .frame(width: entry.isNext ? 13 : 9, height: entry.isNext ? 13 : 9)
                    .shadow(color: entry.isNext ? AppColors.indigo.opacity(0.35) : .clear, radius: 6)
                    .padding(.top, entry.isNext ? 2 : 4)
                if !isLast {
                    Rectangle()
                        .fill(AppColors.indigo.opacity(0.22))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                        .padding(.top, 2)
                }
            }
            .frame(width: 16)

            // Medicine names
            VStack(alignment: .leading, spacing: 6) {
                ForEach(entry.medicineNames, id: \.self) { name in
                    Text(name)
                        .font(.system(size: 14, weight: entry.isNext ? .bold : .medium))
                        .foregroundStyle(entry.isPast ? AppColors.textTertiary : AppColors.textPrimary)
                        .strikethrough(entry.isPast, color: AppColors.textTertiary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Status
            if entry.isNext {
                Text("NEXT")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(AppColors.indigo)
                    .clipShape(Capsule())
                    .padding(.top, 1)
            } else if entry.isPast {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(AppColors.indigo.opacity(0.5))
                    .padding(.top, 1)
            }
        }
        .padding(.vertical, isLast ? 0 : 6)
    }
}
