import SwiftUI
import SwiftData

struct HomeTabView: View {

    // MARK: - Data

    @Query(sort: \ChecklistItem.sortOrder) private var checklistItems: [ChecklistItem]
    @Query(filter: #Predicate<Medicine> { $0.isActive }) private var activeMedicines: [Medicine]
    @Query(sort: \JournalEntry.createdAt, order: .reverse) private var allEntries: [JournalEntry]

    // MARK: - View State

    @State private var showMoodSheet = false
    @State private var preselectedMood: JournalMood? = nil
    @AppStorage("isGeneratingChecklist") private var isGeneratingChecklist = false

    // MARK: - ViewModel

    @State private var viewModel: HomeViewModel

    /// Default init used by the app.
    init() {
        self._viewModel = State(initialValue: HomeViewModel())
    }

    /// Preview init — lets `#Preview` inject a pre-configured ViewModel
    /// so AI states are visible in the canvas without a real device.
    init(previewViewModel: HomeViewModel) {
        self._viewModel = State(initialValue: previewViewModel)
    }

    // MARK: - Derived

    private var vitalsAnomalies: [VitalsAnomaly] {
        VitalsAnomalyDetector.detect(from: allEntries)
    }

    private var hasJournaledToday: Bool {
        allEntries.contains {
            $0.entryType == .journal &&
            Calendar.current.isDateInToday($0.createdAt)
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default:      return "Good evening"
        }
    }

    private var greetingEmoji: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "☀️"
        case 12..<17: return "🌤"
        default:      return "🌙"
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    header
                    VStack(spacing: AppSpacing.lg) {
                        if !hasJournaledToday {
                            aiBriefingCard
                        }
                        if !vitalsAnomalies.isEmpty {
                            anomalyWarningCard
                        }
                        feelingsCard
                        if isGeneratingChecklist {
                            checklistGeneratingCard
                        } else if !checklistItems.isEmpty {
                            DailyChecklistCard(items: checklistItems) { item in
                                withAnimation(.spring(duration: 0.3)) {
                                    item.isChecked.toggle()
                                }
                            }
                        }
                        if !activeMedicines.isEmpty {
                            MedicineScheduleCard(medicines: activeMedicines)
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
            .onAppear {
                resetChecklistIfNeeded()
                viewModel.loadWelcomeInsight(entries: allEntries, anomalies: vitalsAnomalies)
            }
            .sheet(isPresented: $showMoodSheet) {
                JournalMoodSheet(preselectedMood: preselectedMood)
            }
        }
    }

    // MARK: - Glass Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Spacer().frame(height: 56)

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 5) {
                        Text(greetingEmoji)
                            .font(.system(size: 14))
                        Text(greeting.uppercased())
                            .styled(.labelCaps)
                            .foregroundStyle(AppColors.textTertiary)
                    }
                    Text("Wahyu")
                        .styled(.h1)
                        .foregroundStyle(AppColors.textPrimary)
                    Text(Date().formatted(.dateTime.weekday(.wide).day().month(.wide)))
                        .appFont(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
                Spacer()
                if !checklistItems.isEmpty && !isGeneratingChecklist {
                    let done = checklistItems.filter(\.isChecked).count
                    glanceChip(icon: "checkmark.circle.fill", text: "\(done)/\(checklistItems.count)")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppSpacing.xxl)
        .padding(.bottom, AppSpacing.xl)
        .background {
            LinearGradient(
                colors: [AppColors.brand.opacity(0.26), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)
        }
        .overlay(alignment: .bottom) {
            Divider().opacity(0.25)
        }
    }

    private func glanceChip(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppColors.brand)
            Text(text)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppColors.brandDark)
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, 5)
        .background(AppColors.surface)
        .clipShape(Capsule())
        .appShadow(.card)
    }

    // MARK: - AI Daily Briefing Card

    private var aiBriefingCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            // Header row
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppColors.accentViolet, AppColors.sky],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                Text("Daily briefing")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.4)
                    .textCase(.uppercase)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppColors.accentViolet, AppColors.sky],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                Spacer()
            }

            // Content
            if viewModel.isLoadingWelcome {
                HStack(spacing: AppSpacing.md) {
                    AIOrbitLoader(size: 30)
                    Text("Reading your week…")
                        .appFont(.caption)
                        .foregroundStyle(AppColors.textTertiary)
                }
                .transition(.opacity)
            } else if let message = viewModel.aiWelcomeMessage {
                TypingTextView(
                    prompts: [message],
                    typingSpeed: 0.022,
                    font: AppFont.body.font,
                    color: AppColors.textSecondary,
                    loop: false,
                    lineLimit: nil
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(AppSpacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .aiGlow(cornerRadius: AppRadius.lg)
        .animation(.easeInOut(duration: 0.4), value: viewModel.isLoadingWelcome)
        .animation(.easeInOut(duration: 0.4), value: viewModel.aiWelcomeMessage != nil)
    }

    // MARK: - Feelings Card

    private var feelingsCard: some View {
        Button {
            preselectedMood = nil
            showMoodSheet = true
        } label: {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {

                // Title row — prototype: serif "How are you feeling?" + heart icon
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("How are you feeling?")
                            .styled(.h3)
                            .foregroundStyle(AppColors.textPrimary)
                        Text("Tap a mood to start today's entry")
                            .appFont(.caption)
                            .foregroundStyle(AppColors.textTertiary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "heart")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(AppColors.brand)
                }

                // Emoji quick-select row
                HStack(spacing: 0) {
                    ForEach(JournalMood.allCases) { mood in
                        Button {
                            preselectedMood = mood
                            showMoodSheet = true
                        } label: {
                            VStack(spacing: 5) {
                                Text(mood.emoji)
                                    .font(.system(size: 26))
                                Text(mood.rawValue)
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(AppColors.textTertiary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
                .padding(.vertical, AppSpacing.sm)
                .background(AppColors.surface2)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))

                // Fake input field with animated typing prompt
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "pencil.line")
                        .font(.system(size: 14))
                        .foregroundStyle(AppColors.textTertiary)
                    TypingTextView(prompts: [
                        "Tell me how you're doing...",
                        "What's been on your mind?",
                        "How's your energy today?",
                        "Any symptoms to log?",
                        "How did you sleep?"
                    ])
                    Spacer()
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(AppColors.brand)
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.md)
                .background(AppColors.surface2)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
            }
            .padding(AppSpacing.xl)
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
            .appShadow(.card)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Anomaly Warning Card

    private var anomalyWarningCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColors.error)
                Text("Anomali Detected")
                    .appFont(.bodySemibold)
                    .foregroundStyle(AppColors.error)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppColors.error.opacity(0.5))
            }

            ForEach(vitalsAnomalies.prefix(2)) { anomaly in
                HStack(alignment: .top, spacing: AppSpacing.sm) {
                    Circle()
                        .fill(AppColors.error)
                        .frame(width: 5, height: 5)
                        .padding(.top, 6)
                    Text(anomaly.message)
                        .appFont(.caption)
                        .foregroundStyle(AppColors.error.opacity(0.85))
                        .lineSpacing(3)
                }
            }
        }
        .padding(AppSpacing.lg)
        .background(AppColors.errorPale)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.error.opacity(0.35), lineWidth: 1.5)
        }
    }

    // MARK: - Checklist Generating Card

    private var checklistGeneratingCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.md) {
                AIOrbitLoader(size: 44)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Building your daily checklist")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppColors.textPrimary)
                    Text("MedCare AI is reviewing your checkup…")
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.textSecondary)
                }
                Spacer()
            }
            HStack(spacing: AppSpacing.sm) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 20)
                        .fill(AppColors.brandPale)
                        .frame(height: 28)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(AppSpacing.xl)
        .background(AppColors.brandPale.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl))
        .aiGlow(cornerRadius: AppRadius.xl)
    }

    // MARK: - Checklist Reset

    private func resetChecklistIfNeeded() {
        guard !checklistItems.isEmpty else { return }
        let lastReset = UserDefaults.standard.object(forKey: "checklistLastReset") as? Date

        if lastReset == nil || !Calendar.current.isDateInToday(lastReset!) {
            let completed = checklistItems.filter(\.isChecked).count
            ChecklistHistoryStore.shared.recordToday(
                total: checklistItems.count,
                completed: completed
            )
            if completed > 0 {
                UserDefaults.standard.set(Date(), forKey: "checklistLastSaved")
            }
            for item in checklistItems { item.isChecked = false }
            UserDefaults.standard.set(Date(), forKey: "checklistLastReset")
        }
    }
}

// MARK: - Previews

/// Builds a populated in-memory container so all cards are visible in the canvas.
private func makePreviewContainer() -> ModelContainer {
    let container = SwiftDataContainer.create(inMemory: true)
    let ctx = container.mainContext
    let cal = Calendar.current

    // 8 journal entries spanning the past week — enough to trigger VitalsAnomalyDetector
    let bpValues   = ["140/92", "138/90", "142/93", "136/88", "145/94", "139/91", "133/86", "141/92"]
    let hrValues   = [90, 88, 92, 86, 94, 89, 84, 91]
    let tempValues = [37.3, 37.1, 37.5, 37.0, 37.8, 37.2, 36.9, 37.4]
    let titles     = ["Tired & headache", "Low energy", "Neck stiffness", "Feeling better",
                      "Chest tightness", "Poor sleep", "Good day", "Mild headache"]
    let tagSets    = ["headache,fatigue", "fatigue,low-energy", "neck-pain,fatigue", "fatigue",
                      "chest-tightness,fatigue", "poor-sleep,fatigue", "energy", "headache"]

    for i in 0..<8 {
        ctx.insert(JournalEntry(
            title: titles[i],
            content: "Sample journal content for preview day -\(i).",
            entryType: .journal,
            bloodPressure: bpValues[i],
            heartRate: hrValues[i],
            temperature: tempValues[i],
            aiTagsRaw: tagSets[i],
            createdAt: cal.date(byAdding: .day, value: -i, to: Date()) ?? Date()
        ))
    }

    let checklistLabels = ["Take Amlodipine 5mg", "30 min walk", "Drink 8 glasses water", "Check blood pressure"]
    for (idx, label) in checklistLabels.enumerated() {
        let item = ChecklistItem(text: label, sortOrder: idx)
        item.isChecked = idx < 2
        ctx.insert(item)
    }

    ctx.insert(Medicine(name: "Amlodipine", notes: "5mg — once daily in the morning"))

    return container
}

#Preview("Default") {
    HomeTabView()
        .modelContainer(SwiftDataContainer.create(inMemory: true))
}

/// All cards visible + AI warm message — simulates a real device with Apple Intelligence.
#Preview("AI Features Active") {
    let vm = HomeViewModel()
    vm.aiWelcomeMessage = "You've mentioned headaches 3 days in a row — hope you're feeling a bit better today! 💙"

    return HomeTabView(previewViewModel: vm)
        .modelContainer(makePreviewContainer())
}

/// "Personalizing your day..." shimmer — the moment between appear and AI response.
#Preview("AI Loading") {
    let vm = HomeViewModel()
    vm.isLoadingWelcome = true

    return HomeTabView(previewViewModel: vm)
        .modelContainer(makePreviewContainer())
}

/// Anomaly warning card visible — 8 entries with consistently elevated BP trigger the detector.
#Preview("Vitals Anomaly") {
    HomeTabView()
        .modelContainer(makePreviewContainer())
}
