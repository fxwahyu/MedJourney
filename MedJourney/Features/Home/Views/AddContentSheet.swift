import SwiftUI

struct AddContentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var showMoodSheet: Bool
    @Binding var showCheckupSheet: Bool
    @Binding var showMedicineSheet: Bool

    private struct Option {
        let emoji: String
        let title: String
        let sub: String
        let wash: Color
        let action: () -> Void
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            // Drag indicator gap
            Spacer().frame(height: AppSpacing.xs)

            // Serif title — prototype: `className="serif" fontSize 21 fontWeight 500`
            Text("What would you like to log?")
                .styled(.h2)
                .foregroundStyle(AppColors.textPrimary)
                .padding(.horizontal, AppSpacing.xl)
                .padding(.top, AppSpacing.xs)

            VStack(spacing: AppSpacing.md) {
                optionCard(
                    emoji: "🫧",
                    title: "How I'm feeling",
                    sub: "Log mood, symptoms & vitals",
                    wash: AppColors.brand
                ) {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { showMoodSheet = true }
                }

                optionCard(
                    emoji: "🧾",
                    title: "Medical checkup",
                    sub: "Upload results — MedCare AI builds your checklist",
                    wash: AppColors.checkupTeal
                ) {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { showCheckupSheet = true }
                }

                optionCard(
                    emoji: "💊",
                    title: "Add medicine",
                    sub: "Track doses and set reminders",
                    wash: AppColors.rose
                ) {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { showMedicineSheet = true }
                }
            }
            .padding(.horizontal, AppSpacing.xl)

            Spacer()
        }
        .background(AppColors.background)
        .presentationDetents([.height(370)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(AppRadius.screen)
    }

    // MARK: - Card

    private func optionCard(
        emoji: String,
        title: String,
        sub: String,
        wash: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.lg) {
                // 52px tile — wash at 14% on white surface (≈ prototype `color-mix(in srgb, wash 14%, #fff)`)
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(wash.opacity(0.14))
                        .frame(width: 52, height: 52)
                    Text(emoji)
                        .font(.system(size: 25))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .appFont(.bodySemibold)
                        .foregroundStyle(AppColors.textPrimary)
                    Text(sub)
                        .appFont(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColors.textTertiary)
            }
            .padding(AppSpacing.lg)
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
            .appShadow(.card)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

