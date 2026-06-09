import SwiftUI

struct DailyChecklistCard: View {
    let items: [ChecklistItem]
    var onToggle: (ChecklistItem) -> Void

    private var checkedCount: Int { items.filter(\.isChecked).count }
    private var progress: CGFloat { items.isEmpty ? 0 : CGFloat(checkedCount) / CGFloat(items.count) }
    private var isDone: Bool { !items.isEmpty && checkedCount == items.count }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            headerRow
            Divider().foregroundStyle(AppColors.border.opacity(0.5))
            itemsList
        }
        .padding(AppSpacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        // Standard card shadow + subtle aurora glow to signal AI-built content
        .appShadow(.card)
        .shadow(color: AppColors.accentViolet.opacity(0.13), radius: 14, x: 0, y: 4)
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Today's health goals")
                    .appFont(.bodySemibold)
                    .foregroundStyle(AppColors.textPrimary)
                // Prototype: subtitle has "AI-built" in aurora text
                HStack(spacing: 4) {
                    Text(isDone ? "All done — beautiful work 🎉" : "\(checkedCount) of \(items.count) complete")
                        .appFont(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                    Text("· by MedCare AI")
                        .appFont(.caption)
                        .bold()
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppColors.accentViolet, AppColors.sky],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                }
            }

            Spacer()

            // Progress ring
            ZStack {
                Circle()
                    .stroke(AppColors.brand.opacity(0.15), lineWidth: 3.5)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AppColors.brand,
                        style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(duration: 0.5), value: progress)
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(AppColors.brandDark)
            }
            .frame(width: 40, height: 40)
        }
    }

    // MARK: - Items List

    private var itemsList: some View {
        VStack(spacing: AppSpacing.md - 1) {
            ForEach(items.sorted(by: { $0.sortOrder < $1.sortOrder })) { item in
                ChecklistRowView(item: item, onToggle: onToggle)
            }
        }
    }
}

// MARK: - Row

struct ChecklistRowView: View {
    let item: ChecklistItem
    var onToggle: (ChecklistItem) -> Void

    var body: some View {
        Button {
            onToggle(item)
        } label: {
            HStack(spacing: AppSpacing.md - 1) {
                // Circular checkbox — brand fill when checked, soft border when not
                ZStack {
                    Circle()
                        .fill(item.isChecked ? AppColors.brand : Color.clear)
                        .frame(width: 22, height: 22)
                    if !item.isChecked {
                        Circle()
                            .stroke(AppColors.brandSoft, lineWidth: 2)
                            .frame(width: 22, height: 22)
                    }
                    if item.isChecked {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .animation(.easeInOut(duration: 0.18), value: item.isChecked)

                // Label
                Text("\(item.emoji) \(item.text)")
                    .appFont(.body)
                    .foregroundStyle(item.isChecked ? AppColors.textTertiary : AppColors.textPrimary)
                    .strikethrough(item.isChecked, color: AppColors.textTertiary)
                    .multilineTextAlignment(.leading)

                Spacer()
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

#Preview {
    let item = ChecklistItem(id: UUID(), text: "Test", isChecked: false)
    DailyChecklistCard(items: [item], onToggle: { _ in })
        .padding()
        .background(AppColors.background)
}
