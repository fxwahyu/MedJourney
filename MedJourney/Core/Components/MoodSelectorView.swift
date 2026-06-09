import SwiftUI

struct MoodSelectorView: View {
    @Binding var selectedMood: JournalMood?

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("How do you feel today?")
                .styled(.labelCaps)
                .foregroundStyle(AppColors.textTertiary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.sm) {
                    ForEach(JournalMood.allCases) { mood in
                        moodButton(mood)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 4)
            }
        }
    }

    private func moodButton(_ mood: JournalMood) -> some View {
        let isSelected = selectedMood == mood
        return Button {
            withAnimation(.spring(duration: 0.25)) {
                selectedMood = mood
            }
        } label: {
            VStack(spacing: AppSpacing.xs) {
                Text(mood.emoji)
                    .font(.system(size: 30))
                    .scaleEffect(isSelected ? 1.15 : 1.0)

                Text(mood.rawValue)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isSelected ? mood.accentColor : AppColors.textSecondary)
            }
            .frame(width: 68, height: 76)
            .background(isSelected ? mood.selectedBackground : AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .stroke(
                        isSelected ? mood.selectedBorder : AppColors.border,
                        lineWidth: isSelected ? 1.5 : 1
                    )
            }
            .shadow(
                color: isSelected ? mood.accentColor.opacity(0.2) : Color.clear,
                radius: 6, x: 0, y: 3
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

#Preview {
    @Previewable @State var mood: JournalMood? = .good

    MoodSelectorView(selectedMood: $mood)
        .padding(AppSpacing.xxl)
        .background(AppColors.background)
}
