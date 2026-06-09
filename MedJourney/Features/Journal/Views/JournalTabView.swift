import SwiftUI
import SwiftData

struct JournalTabView: View {
    @Query(sort: \JournalEntry.createdAt, order: .reverse) private var entries: [JournalEntry]

    @State private var selectedEntry: JournalEntry?
    @State private var showCheckup = false
    @State private var showMoodEntry = false
    @State private var filterType: JournalEntry.EntryType? = nil

    private var filteredEntries: [JournalEntry] {
        guard let type = filterType else { return entries }
        return entries.filter { $0.entryType == type }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    header
                    VStack(spacing: AppSpacing.md) {
                        filterRow
                        entryList
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.top, AppSpacing.lg)
                    .padding(.bottom, 120)
                }
            }
            .ignoresSafeArea(edges: .top)
            .background(AppColors.background)
            .navigationBarHidden(true)
            .sheet(isPresented: $showCheckup) { CheckupUploadView() }
            .sheet(isPresented: $showMoodEntry) { JournalMoodSheet() }
            .sheet(item: $selectedEntry) { JournalEntryDetailView(entry: $0) }
        }
    }

    // MARK: - Header (flat)

    private var header: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Spacer().frame(height: 56)

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Journal")
                        .styled(.labelCaps)
                        .foregroundStyle(AppColors.textTertiary)
                    Text("Health journal")
                        .styled(.h1)
                        .foregroundStyle(AppColors.textPrimary)
                    Text("\(entries.count) entries recorded")
                        .appFont(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
                Spacer()
            }

//            HStack(spacing: AppSpacing.sm) {
//                quickActionButton(icon: "heart.text.square", label: "Log Feeling") {
//                    showMoodEntry = true
//                }
//                quickActionButton(icon: "doc.badge.plus", label: "Upload Checkup") {
//                    showCheckup = true
//                }
//            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppSpacing.xxl)
        .padding(.bottom, AppSpacing.xl)
        .background {
            ZStack {
                LinearGradient(
                    colors: [AppColors.checkupTeal.opacity(0.28), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea(edges: .top)
//                Rectangle()
//                    .fill(.ultraThinMaterial)
//                    .ignoresSafeArea(edges: .top)
            }
        }
        .overlay(alignment: .bottom) {
            Divider().opacity(0.25)
        }
    }

    private func quickActionButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(AppColors.brandDark)
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(AppColors.brandPale)
            .clipShape(Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Filter Row

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.sm) {
                filterChip(label: "All", type: nil)
                ForEach(JournalEntry.EntryType.allCases) { type in
                    filterChip(label: type.displayName, type: type)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func filterChip(label: String, type: JournalEntry.EntryType?) -> some View {
        let isSelected = filterType == type
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { filterType = type }
        } label: {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isSelected ? .white : AppColors.textSecondary)
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
                .background(isSelected ? AppColors.checkupTeal : AppColors.surface)
                .clipShape(Capsule())
                .overlay {
                    Capsule().stroke(isSelected ? Color.clear : AppColors.border, lineWidth: 1)
                }
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Entry List

    private var entryList: some View {
        Group {
            if filteredEntries.isEmpty {
                LoadingStateView(state: .empty(
                    title: "No entries yet",
                    message: "Tap + or use the buttons above to create your first entry.",
                    icon: "heart.text.square"
                ))
                .frame(minHeight: 260)
            } else {
                VStack(spacing: AppSpacing.md) {
                    ForEach(filteredEntries) { entry in
                        JournalCardView(entry: entry)
                            .onTapGesture { selectedEntry = entry }
                    }
                }
            }
        }
    }
}

#Preview {
    JournalTabView()
        .modelContainer(SwiftDataContainer.create(inMemory: true))
}
