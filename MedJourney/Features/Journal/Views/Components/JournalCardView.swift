//
//  JournalCardView.swift
//  MedJourney
//
//  Created by user on 19/05/26.
//

import SwiftUI

struct JournalCardView: View {
    @State var entry: JournalEntry
    
    init(entry: JournalEntry) {
        self.entry = entry
    }
    
    var body: some View {
        AppCard(showBorder: true, borderColor: AppColors.border) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack {
                    BadgePill(
                        entry.entryType.displayName,
                        style: badgeStyle(for: entry.entryType),
                        icon: entry.entryType.iconName
                    )
                    Spacer()
                    Text(entry.createdAt, style: .relative)
                        .appFont(.caption)
                        .foregroundStyle(AppColors.textTertiary)
                }

                Text(entry.title)
                    .appFont(.bodySemibold)
                    .foregroundStyle(AppColors.textPrimary)

                Text(entry.content)
                    .appFont(.caption)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(2)

                if let level = entry.discomfortLevel {
                    HStack(spacing: AppSpacing.xs) {
                        Text("Discomfort:")
                            .appFont(.caption)
                            .foregroundStyle(AppColors.textTertiary)
                        Text("\(level)/10")
                            .appFont(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(level > 7 ? AppColors.error : AppColors.accentOrange)
                    }
                }
            }
        }
    }
    
    private func badgeStyle(for type: JournalEntry.EntryType) -> BadgePill.Style {
        switch type {
        case .journal: return .accent
        case .checkup: return .violet
        case .medication: return .brand
        }
    }
}
