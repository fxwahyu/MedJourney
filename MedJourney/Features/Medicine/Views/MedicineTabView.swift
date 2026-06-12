import SwiftUI
import SwiftData

struct MedicineTabView: View {

    @Query(sort: \Medicine.createdAt, order: .reverse) private var medicines: [Medicine]
    @Environment(\.modelContext) private var context

    @State private var showAddMedicine = false
    @State private var viewModel = MedicineViewModel()

    private var activeMedicines: [Medicine] { medicines.filter(\.isActive) }
    private var inactiveMedicines: [Medicine] { medicines.filter { !$0.isActive } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    header
                    VStack(spacing: AppSpacing.lg) {
                        if medicines.isEmpty {
                            emptyState
                        } else {
                            if !activeMedicines.isEmpty {
                                medicineSection(title: "Active", medicines: activeMedicines, isActive: true)
                            }
                            if !inactiveMedicines.isEmpty {
                                medicineSection(title: "Paused", medicines: inactiveMedicines, isActive: false)
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.top, AppSpacing.xl)
                    .padding(.bottom, 120)
                }
            }
            .ignoresSafeArea(edges: .top)
            .background(AppColors.background)
            .navigationBarHidden(true)
            .sheet(isPresented: $showAddMedicine) {
                AddMedicineView()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Spacer().frame(height: 56)

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Medication")
                        .styled(.labelCaps)
                        .foregroundStyle(AppColors.textTertiary)
                    Text("My medicines")
                        .styled(.h1)
                        .foregroundStyle(AppColors.textPrimary)
                    Text("\(activeMedicines.count) active · \(medicines.count) total")
                        .appFont(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
                Spacer()
                Button { showAddMedicine = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .bold))
                        Text("Add")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(AppColors.rose)
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
                    .background(AppColors.rosePale)
                    .clipShape(Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppSpacing.xxl)
        .padding(.bottom, AppSpacing.xl)
        .background {
            LinearGradient(
                colors: [AppColors.rose.opacity(0.4), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)
        }
        .overlay(alignment: .bottom) {
            Divider().opacity(0.25)
        }
    }

    // MARK: - Section

    private func medicineSection(title: String, medicines: [Medicine], isActive: Bool) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(title.uppercased())
                .styled(.labelCaps)
                .foregroundStyle(AppColors.textTertiary)

            ForEach(medicines) { medicine in
                MedicineCardView(medicine: medicine) {
                    viewModel.toggleActive(medicine)
                } onDelete: {
                    viewModel.deleteMedicine(medicine, context: context)
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: AppSpacing.lg) {
            FeatureCard(gradient: AppGradients.medicine, minHeight: 160) {
                ZStack {
                    FloatingSparkles()
                    VStack(spacing: AppSpacing.md) {
                        Image(systemName: "pills.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.white.opacity(0.7))
                        Text("No medicines yet")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                        Text("Add your first medicine to get reminders and track your treatment")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                        Button {
                            showAddMedicine = true
                        } label: {
                            Text("Add Medicine")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(AppColors.rose)
                                .padding(.horizontal, AppSpacing.xl)
                                .padding(.vertical, AppSpacing.sm)
                                .background(Color.white)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

// MARK: - Medicine Card

struct MedicineCardView: View {
    let medicine: Medicine
    var onToggle: () -> Void
    var onDelete: () -> Void

    var body: some View {
        AppCard(showBorder: true) {
            HStack(spacing: AppSpacing.md) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: AppRadius.sm)
                        .fill(medicine.isActive ? AppColors.rosePale : AppColors.surface2)
                        .frame(width: 48, height: 48)
                    Image(systemName: "pills.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(medicine.isActive ? AppColors.rose : AppColors.textTertiary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(medicine.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary)

                    if !medicine.notes.isEmpty {
                        Text(medicine.notes)
                            .font(.system(size: 12))
                            .foregroundStyle(AppColors.textSecondary)
                            .lineLimit(2)
                    }

                    // Time chips
                    if !medicine.notificationTimes.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: AppSpacing.xs) {
                                ForEach(medicine.notificationTimes, id: \.self) { time in
                                    HStack(spacing: 3) {
                                        Image(systemName: "bell.fill")
                                            .font(.system(size: 9))
                                        Text(time)
                                            .font(.system(size: 10, weight: .semibold))
                                    }
                                    .foregroundStyle(medicine.isActive ? AppColors.rose : AppColors.textTertiary)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(medicine.isActive ? AppColors.rosePale : AppColors.surface2)
                                    .clipShape(Capsule())
                                }
                            }
                        }
                    }
                }

                Spacer()

                // Active toggle
                Button(action: onToggle) {
                    Image(systemName: medicine.isActive ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(medicine.isActive ? AppColors.rose : AppColors.brandDark)
                }
                .buttonStyle(.plain)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

#Preview {
    MedicineTabView()
        .modelContainer(SwiftDataContainer.create(inMemory: true))
}
