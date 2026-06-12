import SwiftUI
import SwiftData

struct JournalMoodSheet: View {

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var preselectedMood: JournalMood? = nil

    @State private var viewModel = JournalEntryViewModel()
    @State private var showVitals = false

    var body: some View {
        @Bindable var vm = viewModel
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.xl) {
                    moodGridSection
                    journalPromptHint
                    journalTextSection($vm)
                    vitalsToggleSection($vm)
                    saveButton
                }
                .padding(AppSpacing.xxl)
                .animation(.easeInOut(duration: 0.25), value: viewModel.selectedMood)
            }
            .background(AppColors.background)
            .navigationTitle("How are you feeling?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(AppColors.brandDark)
                }
            }
            // Urgency alert — shown when Foundation Models detects red-flag language
            .alert("Urgent Health Concern", isPresented: $viewModel.showUrgencyAlert) {
                Button("Seek Medical Attention") { }
                Button("Save Entry Anyway", role: .destructive) {
                    viewModel.acknowledgeUrgencyAndSave(context: context, dismiss: dismiss)
                }
            } message: {
                let keywords = viewModel.urgentKeywords.isEmpty
                    ? "concerning language"
                    : viewModel.urgentKeywords.joined(separator: ", ")
                Text("Your entry mentions \(keywords). If you are experiencing a medical emergency, please contact emergency services or seek immediate medical attention.")
            }
        }
        .onAppear {
            if let mood = preselectedMood {
                viewModel.selectedMood = mood
            }
            viewModel.loadJournalPrompt()
        }
    }

    // MARK: - Mood Grid

    private var moodGridSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                Text("Choose your mood")
                    .styled(.labelCaps)
                    .foregroundStyle(AppColors.textTertiary)
                Spacer()
                if viewModel.selectedMood != nil {
                    Text(viewModel.selectedMood!.emoji)
                        .font(.system(size: 22))
                        .transition(.scale.combined(with: .opacity))
                }
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: AppSpacing.sm), count: 4),
                spacing: AppSpacing.sm
            ) {
                ForEach(JournalMood.allCases) { mood in
                    moodCell(mood)
                }
            }
        }
    }

    private func moodCell(_ mood: JournalMood) -> some View {
        let isSelected = viewModel.selectedMood == mood
        return Button {
            withAnimation(.spring(duration: 0.28)) {
                viewModel.selectedMood = mood
            }
        } label: {
            VStack(spacing: AppSpacing.xs) {
                Text(mood.emoji)
                    .font(.system(size: 34))
                    .scaleEffect(isSelected ? 1.1 : 1.0)
                Text(mood.rawValue)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isSelected ? mood.accentColor : AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.md)
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
                color: isSelected ? mood.accentColor.opacity(0.22) : .clear,
                radius: 8, x: 0, y: 3
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Journal Opening Prompt (reused from the Home AI briefing)

    @ViewBuilder
    private var journalPromptHint: some View {
        if viewModel.isLoadingPrompt {
            HStack(spacing: AppSpacing.sm) {
                ProgressView()
                    .scaleEffect(0.75)
                    .tint(AppColors.sky)
                Text("MedCare AI is personalizing your prompt…")
                    .appFont(.caption)
                    .foregroundStyle(AppColors.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.md)
            .background(AppColors.accentVioletPale)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
            .transition(.opacity)
        } else if let prompt = viewModel.journalOpeningPrompt {
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColors.accentViolet)
                    .padding(.top, 2)
                Text(prompt)
                    .appFont(.body)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineSpacing(4)
                    .multilineTextAlignment(.leading)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.accentVioletPale)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    // MARK: - Journal Text

    private func journalTextSection(_ vm: Bindable<JournalEntryViewModel>) -> some View {
        AppTextArea(
            "What's on your mind?",
            text: vm.entryContent,
            placeholder: "Describe how you feel — symptoms, energy level, what's been happening...",
            maxCharacters: 500
        )
    }

    // MARK: - Optional Vitals

    private func vitalsToggleSection(_ vm: Bindable<JournalEntryViewModel>) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Button {
                withAnimation(.easeInOut(duration: 0.22)) { showVitals.toggle() }
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(AppColors.brandPale)
                            .frame(width: 32, height: 32)
                        Image(systemName: "heart.text.square.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(AppColors.brandDark)
                    }
                    Text("Optional Vitals")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary)
                    Spacer()
                    Image(systemName: showVitals ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppColors.textTertiary)
                }
                .padding(AppSpacing.lg)
                .background(AppColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                .overlay {
                    RoundedRectangle(cornerRadius: AppRadius.md)
                        .stroke(AppColors.border, lineWidth: 1)
                }
            }
            .buttonStyle(.plain)

            if showVitals {
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: AppSpacing.md
                ) {
                    AppTextField(
                        "Blood pressure", text: vm.bloodPressure,
                        placeholder: "120/80", suffix: "mmHg",
                        keyboardType: .numbersAndPunctuation
                    )
                    AppTextField(
                        "Heart rate", text: vm.heartRate,
                        placeholder: "72", suffix: "bpm",
                        keyboardType: .numberPad
                    )
                    AppTextField(
                        "Temperature", text: vm.temperature,
                        placeholder: "36.6", suffix: "°C",
                        keyboardType: .decimalPad
                    )
                    AppTextField(
                        "Weight", text: vm.weight,
                        placeholder: "70", suffix: "kg",
                        keyboardType: .decimalPad
                    )
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Save

    private var saveButton: some View {
        AppButton(
            viewModel.isPreProcessing ? "Checking..." : "Save Journal Entry",
            style: .primary,
            icon: viewModel.isPreProcessing ? nil : "checkmark",
            isFullWidth: true,
            isLoading: viewModel.isPreProcessing
        ) {
            viewModel.saveEntry(context: context, dismiss: dismiss)
        }
    }
}

#Preview {
    JournalMoodSheet()
        .modelContainer(SwiftDataContainer.create(inMemory: true))
}
