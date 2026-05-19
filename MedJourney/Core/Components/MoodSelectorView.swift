//
//  MoodSelectorView.swift
//  MedJourney
//
//  Components — Reusable mood selector (4 options)
//

import SwiftUI

/// A row of 4 tappable mood buttons: Sick, Low, Neutral, Fit.
///
/// Fully reusable — accepts a binding to the selected mood so
/// it can be dropped into any screen.
///
/// Usage:
/// ```swift
/// @State private var mood: JournalMood? = nil
///
/// MoodSelectorView(selectedMood: $mood)
/// ```
struct MoodSelectorView: View {

    @Binding var selectedMood: JournalMood?

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("How do you feel today?")
                .styled(.labelCaps)
                .foregroundStyle(AppColors.textTertiary)

            HStack(spacing: AppSpacing.sm) {
                ForEach(JournalMood.allCases) { mood in
                    moodButton(mood)
                }
            }
        }
    }

    // MARK: - Mood Button

    private func moodButton(_ mood: JournalMood) -> some View {
        let isSelected = selectedMood == mood

        return Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                selectedMood = mood
            }
        } label: {
            RoundedRectangle(cornerRadius: AppRadius.sm)
                .fill(isSelected ? mood.selectedBackground : AppColors.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: AppRadius.sm)
                        .stroke(
                            isSelected ? mood.selectedBorder : AppColors.border,
                            lineWidth: isSelected ? 1.5 : 1
                        )
                }
                .overlay {
                    VStack(spacing: AppSpacing.sm) {
                        Text(mood.emoji)
                            .font(.system(size: 28))
                        
                        Text(mood.rawValue)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(isSelected ? mood.accentColor : AppColors.textSecondary)
                    }
                    .padding(.vertical, AppSpacing.md)
                }
                .frame(maxWidth: .infinity, minHeight: 76)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

#Preview {
    @Previewable @State var mood: JournalMood? = .low

    MoodSelectorView(selectedMood: $mood)
        .padding(AppSpacing.xxl)
        .background(AppColors.background)
}
