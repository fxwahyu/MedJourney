import SwiftUI

/// Journal entry card: leading category tile + title/meta + optional vitals row + tag pills.
struct JournalCardView: View {
    let entry: JournalEntry

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {

            // MARK: - Header row: tile + title + meta + analyzed badge
            HStack(spacing: AppSpacing.md) {
                // 38pt category tile
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(typePaleColor)
                        .frame(width: 38, height: 38)
                    if let mood = entryMood {
                        Text(mood.emoji)
                            .font(.system(size: 20))
                    } else {
                        Image(systemName: typeIcon)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(typeColor)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.title)
                        .appFont(.bodySemibold)
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1)
                    Text("\(entry.createdAt.relativeFormatted) · \(entry.entryType.displayName)")
                        .appFont(.small)
                        .foregroundStyle(AppColors.textTertiary)
                }

                Spacer(minLength: 0)

                // "Analyzed" aurora pill for AI'd checkups
                if entry.entryType == .checkup && !entry.aiTags.isEmpty {
                    AISparkleTag(label: "Analyzed")
                }
            }

            // MARK: - Body text (2-line clamp)
            if !entry.content.isEmpty {
                Text(entry.content)
                    .appFont(.body)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(2)
                    .lineSpacing(3)
            }

            // MARK: - Vitals row (mono chips)
            if hasVitals {
                HStack(spacing: AppSpacing.md) {
                    if let bp = entry.bloodPressure, !bp.isEmpty {
                        vitalChip(icon: "drop.fill", value: bp, unit: "mmHg")
                    }
                    if let hr = entry.heartRate {
                        vitalChip(icon: "waveform.path.ecg", value: "\(hr)", unit: "bpm")
                    }
                    if let temp = entry.temperature {
                        vitalChip(icon: "thermometer.medium", value: String(format: "%.1f", temp), unit: "°C")
                    }
                }
            }

            // MARK: - Tags
            if !entry.aiTags.isEmpty {
                tagPillsRow(entry.aiTags)
            } else if entry.entryType == .journal {
                Text("Generating tags…")
                    .appFont(.small)
                    .foregroundStyle(AppColors.textTertiary)
                    .italic()
            }
        }
        .padding(AppSpacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.border, lineWidth: 1)
        }
        .appShadow(.card)
    }

    // MARK: - Vitals

    private var hasVitals: Bool {
        (entry.bloodPressure != nil && !(entry.bloodPressure?.isEmpty ?? true))
        || entry.heartRate != nil
        || entry.temperature != nil
    }

    private func vitalChip(icon: String, value: String, unit: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppColors.textTertiary)
            Text(value)
                .font(.custom("DMMono-Medium", size: 12))
                .foregroundStyle(AppColors.textPrimary)
            Text(unit)
                .appFont(.small)
                .foregroundStyle(AppColors.textTertiary)
        }
    }

    // MARK: - Tags

    private func tagPillsRow(_ tags: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.xs) {
                ForEach(Array(tags.prefix(4).enumerated()), id: \.offset) { _, tag in
                    Text(tag)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(tagForeground)
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.vertical, 4)
                        .background(tagBackground)
                        .clipShape(Capsule())
                }
            }
        }
    }

    // MARK: - Type Helpers

    private var entryMood: JournalMood? {
        guard entry.entryType == .journal else { return nil }
        return JournalMood.allCases.first { $0.rawValue == entry.title }
            ?? JournalMood.allCases.first { entry.title.lowercased().contains($0.rawValue.lowercased()) }
    }

    private var typeColor: Color {
        switch entry.entryType {
        case .journal:    return AppColors.brand
        case .checkup:    return AppColors.checkupTeal
        case .medication: return AppColors.rose
        }
    }

    private var typePaleColor: Color {
        switch entry.entryType {
        case .journal:    return AppColors.brandPale
        case .checkup:    return Color(hex: "E2F1F4")
        case .medication: return AppColors.rosePale
        }
    }

    private var typeIcon: String {
        switch entry.entryType {
        case .journal:    return "heart.fill"
        case .checkup:    return "doc.text.fill"
        case .medication: return "pills.fill"
        }
    }

    // Tags use checkupTeal for checkup, brand for journal
    private var tagBackground: Color {
        switch entry.entryType {
        case .checkup:    return Color(hex: "E2F1F4")
        default:          return AppColors.brandPale
        }
    }

    private var tagForeground: Color {
        switch entry.entryType {
        case .checkup:    return AppColors.checkupTeal
        default:          return AppColors.brandDark
        }
    }
}

// MARK: - Date Extension

private extension Date {
    var relativeFormatted: String {
        let diff = Calendar.current.dateComponents([.minute, .hour, .day], from: self, to: Date())
        if let days = diff.day, days > 0 { return days == 1 ? "Yesterday" : "\(days)d ago" }
        if let hours = diff.hour, hours > 0 { return "\(hours)h ago" }
        if let mins = diff.minute, mins > 1 { return "\(mins)m ago" }
        return "Just now"
    }
}
