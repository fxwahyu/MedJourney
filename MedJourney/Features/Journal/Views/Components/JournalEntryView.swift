//
//  JournalEntryView.swift
//  MedJourney
//
//  Created by user on 19/05/26.
//

import SwiftUI
import SwiftData
import PhotosUI

/// New journal entry form.
///
/// This view is purely declarative — all state and logic live in
/// `JournalEntryViewModel`. Reusable components (`MoodSelectorView`,
/// `PainSliderView`) are composed here without inline implementation.
struct JournalEntryView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: JournalEntryViewModel

    /// Default init — used everywhere in the app.
    init() { self._viewModel = State(initialValue: JournalEntryViewModel()) }

    /// Preview init — lets `#Preview` inject a pre-configured ViewModel so all UI states
    /// (live tags, prompts, etc.) are visible in the canvas without a real device.
    init(previewViewModel: JournalEntryViewModel) {
        self._viewModel = State(initialValue: previewViewModel)
    }

    // Local data for journal prompt context
    @Query(sort: \JournalEntry.createdAt, order: .reverse) private var recentEntries: [JournalEntry]
    @Query(sort: \ChecklistItem.sortOrder) private var checklistItems: [ChecklistItem]
    @Query(filter: #Predicate<Medicine> { $0.isActive }) private var activeMedicines: [Medicine]

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.xl) {
                    entryTypeSelector
                    Divider()

                    switch viewModel.entryType {
                        case .journal:   journalSection
                        case .checkup:   medicalAnalysisSection
                        case .medication: medicationSection
                    }

                    AppButton(
                        viewModel.isPreProcessing ? "Checking..." : "Save Entry",
                        style: .primary,
                        icon: viewModel.isPreProcessing ? nil : "checkmark",
                        isFullWidth: true,
                        isLoading: viewModel.isPreProcessing
                    ) {
                        viewModel.saveEntry(context: modelContext, dismiss: dismiss)
                    }
                }
                .padding(AppSpacing.xxl)
            }
            .background(AppColors.background)
            .navigationTitle(viewModel.entryType.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(AppColors.brandDark)
                }
            }
            .alert("About AI Analysis", isPresented: $viewModel.showAIDisclaimer) {
                Button("I understand") { viewModel.analyzeWithAI() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("MedCare AI reviews your documents and journal to surface helpful observations — not diagnoses. Always discuss results with your healthcare provider before making any health decisions.")
            }
            // Urgency alert — shown when Foundation Models detects red-flag language
            .alert("Urgent Health Concern", isPresented: $viewModel.showUrgencyAlert) {
                Button("Seek Medical Attention") { }
                Button("Save Entry Anyway", role: .destructive) {
                    viewModel.acknowledgeUrgencyAndSave(context: modelContext, dismiss: dismiss)
                }
            } message: {
                let keywords = viewModel.urgentKeywords.isEmpty
                    ? "concerning language"
                    : viewModel.urgentKeywords.joined(separator: ", ")
                Text("Your entry mentions \(keywords). If you are experiencing a medical emergency, please contact emergency services or seek immediate medical attention.")
            }
        }
    }
    // MARK: - onAppear
    // Loads journal opening prompt from local data (on-device, zero Gemini tokens)
    private func loadPromptIfNeeded() {
        guard viewModel.entryType == .journal else { return }
        viewModel.loadJournalPrompt(
            entries: Array(recentEntries.prefix(20)),
            checklistItems: checklistItems,
            medicines: activeMedicines
        )
    }

    // MARK: - Entry Type Selector

    private var entryTypeSelector: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Entry Type")
                .styled(.labelCaps)
                .foregroundStyle(AppColors.textTertiary)

            HStack(spacing: AppSpacing.sm) {
                ForEach(JournalEntry.EntryType.allCases) { type in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.entryType = type
                        }
                    } label: {
                        HStack(spacing: AppSpacing.xs) {
                            Image(systemName: type.iconName)
                                .font(.system(size: 12, weight: .semibold))
                            Text(type.displayName)
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.sm)
                        .frame(maxHeight: 40)
                        .background(viewModel.entryType == type ? AppColors.brandPale : AppColors.surface)
                        .foregroundStyle(viewModel.entryType == type ? AppColors.brandDark : AppColors.textSecondary)
                        .clipShape(Capsule())
                        .overlay {
                            Capsule().stroke(
                                viewModel.entryType == type ? AppColors.brandSoft : AppColors.border,
                                lineWidth: 1
                            )
                        }
                    }
                }
                Spacer()
            }
        }
    }

    private var journalSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xl) {
            // Reusable mood selector
            MoodSelectorView(selectedMood: $viewModel.selectedMood)
                .onChange(of: viewModel.selectedMood) { _, mood in
                    if mood?.showsPainSlider == false { viewModel.painLevel = 0 }
                }

            // Reusable pain slider — shown conditionally
            if viewModel.selectedMood?.showsPainSlider == true {
                PainSliderView(painLevel: $viewModel.painLevel)
            }

            // Foundation Models journal opening prompt (on-device, zero Gemini tokens)
            journalPromptHint

            AppTextArea(
                "What's on your mind?",
                text: $viewModel.entryContent,
                placeholder: "Describe what you're experiencing — any symptoms, how long it's been going on, what makes it better or worse...",
                maxCharacters: 500
            )
            .onChange(of: viewModel.entryContent) { _, _ in
                viewModel.scheduleLiveTagGeneration()
            }

            // Live AI tag strip — appears as the user types, powered by on-device Foundation Models
            if viewModel.isGeneratingLiveTags || !viewModel.liveTagSuggestions.isEmpty {
                liveTagsStrip
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            quickVitalsSection
        }
        .onAppear { loadPromptIfNeeded() }
    }

    @ViewBuilder
    private var journalPromptHint: some View {
        if viewModel.isLoadingPrompt {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.brand)
                    .symbolEffect(.variableColor.iterative.reversing)
                Text("MedCare AI is personalizing your prompt…")
                    .font(.system(size: 13))
                    .foregroundStyle(AppColors.textTertiary)
            }
        } else if let prompt = viewModel.journalOpeningPrompt {
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppColors.brand)
                    .padding(.top, 2)
                Text(prompt)
                    .font(.system(size: 14))
                    .foregroundStyle(AppColors.textSecondary)
                    .lineSpacing(3)
                    .multilineTextAlignment(.leading)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(AppColors.brandPale.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .stroke(AppColors.brandSoft.opacity(0.6), lineWidth: 1)
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    // MARK: - Live Tags Strip

    /// Shows Foundation Models-generated tags as the user types.
    /// The sparkles icon pulses while generation is in progress.
    private var liveTagsStrip: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "sparkles")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppColors.brand)
                .symbolEffect(
                    .variableColor.iterative.reversing,
                    isActive: viewModel.isGeneratingLiveTags
                )

            if viewModel.isGeneratingLiveTags && viewModel.liveTagSuggestions.isEmpty {
                Text("MedCare AI is listening…")
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.textTertiary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.xs) {
                        ForEach(viewModel.liveTagSuggestions, id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(AppColors.brandDark)
                                .padding(.horizontal, AppSpacing.sm)
                                .padding(.vertical, 3)
                                .background(AppColors.brandPale)
                                .clipShape(Capsule())
                                .transition(.scale(scale: 0.85).combined(with: .opacity))
                        }
                    }
                }
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.brandPale.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.sm)
                .stroke(AppColors.brandSoft.opacity(0.5), lineWidth: 1)
        }
    }

    // MARK: - Quick Vitals Section

    private var quickVitalsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: AppSpacing.md
            ) {
                AppTextField(
                    "Blood pressure",
                    text: $viewModel.bloodPressure,
                    placeholder: "120/80",
                    suffix: "mmHg",
                    keyboardType: .numbersAndPunctuation
                )

                AppTextField(
                    "Heart rate",
                    text: $viewModel.heartRate,
                    placeholder: "72",
                    suffix: "bpm",
                    keyboardType: .numberPad
                )

                AppTextField(
                    "Temperature",
                    text: $viewModel.temperature,
                    placeholder: "36.6",
                    suffix: "°C",
                    keyboardType: .decimalPad
                )

                AppTextField(
                    "Weight",
                    text: $viewModel.weight,
                    placeholder: "70",
                    suffix: "kg",
                    keyboardType: .decimalPad
                )
            }
        }
    }

    // MARK: - Medical Analysis Section

    private var medicalAnalysisSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xl) {

            // Upload header
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text("Upload Documents")
                    .styled(.labelCaps)
                    .foregroundStyle(AppColors.textTertiary)

                Text("Choose an image of your medical records, lab results, or prescriptions.")
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.textSecondary)
                    .lineSpacing(4)

                // Photo picker
                PhotosPicker(
                    selection: $viewModel.selectedPhotoItems,
                    maxSelectionCount: 5,
                    matching: .images
                ) {
                    HStack(spacing: AppSpacing.md) {
                        ZStack {
                            RoundedRectangle(cornerRadius: AppRadius.sm)
                                .fill(AppColors.brandPale)
                                .frame(width: 44, height: 44)
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 18))
                                .foregroundStyle(AppColors.brandDark)
                        }
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text("Choose Photos")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(AppColors.textPrimary)
                            Text("Select up to 5 images from your library")
                                .font(.system(size: 12))
                                .foregroundStyle(AppColors.textTertiary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
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

                // Uploaded thumbnails
                if !viewModel.uploadedImages.isEmpty {
                    uploadedImagesPreview
                }
            }

            // AI Analysis Section
            if !viewModel.uploadedImages.isEmpty {
                if viewModel.isAnalyzingAI {
                    aiCookingState
                } else if let analysis = viewModel.aiAnalysis {
                    aiAnalysisResult(analysis: analysis)
                } else {
                    aiDiagnoseButton
                }
            }

            AppTextArea(
                "Additional Notes",
                text: $viewModel.entryContent,
                placeholder: "Any context about your checkup, what the doctor said...",
                maxCharacters: 500
            )
        }
    }

    // MARK: - AI Analysis UI

    private var aiDiagnoseButton: some View {
        AppCard(
            shadowLevel: .elevated,
            showBorder: true,
            borderColor: AppColors.brand.opacity(0.3)
        ) {
            HStack(spacing: AppSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppRadius.sm)
                        .fill(AppColors.brandPale)
                        .frame(width: 44, height: 44)
                    Image(systemName: "sparkles")
                        .font(.system(size: 18))
                        .foregroundStyle(AppColors.brandDark)
                }
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Show AI Diagnose")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary)
                    Text("MedCare AI analysis of your documents")
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.textTertiary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.brandDark)
            }
        }
        .onTapGesture { viewModel.showAIDisclaimer = true }
        .transition(.opacity.combined(with: .scale(scale: 0.97)))
    }

    private var aiCookingState: some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: "sparkles")
                .font(.system(size: 24))
                .foregroundStyle(AppColors.brandDark)
                .symbolEffect(.variableColor.iterative.reversing)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("MedCare AI is reviewing…")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary)
                Text("Extracting text and analyzing results")
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.textSecondary)
            }
            .shimmer()
        }
        .padding(AppSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.brandPale.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.md)
                .stroke(AppColors.brandSoft, lineWidth: 1)
        }
        .transition(.opacity)
    }

    private func aiAnalysisResult(analysis: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: "sparkles")
                    .foregroundStyle(AppColors.brandDark)
                Text("MedCare AI Insights")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary)
            }
            
            if let tags = viewModel.aiTags {
                tagPillsRow(tags)
            }
            
            Divider()

            MarkdownAnalysisView(markdown: analysis)
        }
        .padding(AppSpacing.lg)
        .background(AppColors.brandPale.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.md)
                .stroke(AppColors.brandSoft, lineWidth: 1)
        }
        .transition(.opacity)
    }

    private func tagPillsRow(_ tags: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.xs) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppColors.brandDark)
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.vertical, 4)
                        .background(AppColors.brandPale)
                        .clipShape(Capsule())
                }
            }
        }
    }

    // MARK: - Uploaded Images Preview

    private var uploadedImagesPreview: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("\(viewModel.uploadedImages.count) file(s) selected")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppColors.brandDark)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.sm) {
                    ForEach(viewModel.uploadedImages.indices, id: \.self) { index in
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: viewModel.uploadedImages[index])
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))

                            Button {
                                viewModel.removeImage(at: index)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(AppColors.error)
                                    .background(Circle().fill(Color.white))
                            }
                            .offset(x: 6, y: -6)
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.xs)
                .padding(.vertical, AppSpacing.sm)
            }
        }
    }

    // MARK: - Medication Section

    private var medicationSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xl) {
            AppTextField(
                "Medication Name",
                text: $viewModel.medicationName,
                placeholder: "e.g. Paracetamol 500mg",
                icon: "pills"
            )

            AppTextArea(
                "Notes",
                text: $viewModel.medicationNotes,
                placeholder: "Dosage, timing, any side effects noticed...",
                minHeight: 100,
                maxCharacters: 300
            )
        }
    }
}

// MARK: - Previews

#Preview("Default") {
    JournalEntryView()
        .modelContainer(SwiftDataContainer.create(inMemory: true))
}

/// Shows the Foundation Models live-tag strip and the AI opening prompt,
/// exactly as they appear on a device with Apple Intelligence enabled.
#Preview("AI Features Active") {
    let vm = JournalEntryViewModel()
    vm.entryContent = "I've been having a headache all morning and feeling really tired. My neck is also stiff and I haven't been sleeping well."
    vm.liveTagSuggestions = ["headache", "fatigue", "neck stiffness", "poor sleep"]
    vm.isGeneratingLiveTags = false
    vm.journalOpeningPrompt = "You mentioned headaches a few times this week — how's your head feeling compared to yesterday?"
    vm.selectedMood = .neutral

    return JournalEntryView(previewViewModel: vm)
        .modelContainer(SwiftDataContainer.create(inMemory: true))
}

/// Shows the animated "AI listening..." state right after the user pauses typing.
#Preview("Live Tags — Detecting") {
    let vm = JournalEntryViewModel()
    vm.entryContent = "Feeling dizzy when I stand up quickly, and my chest feels a little tight."
    vm.liveTagSuggestions = []
    vm.isGeneratingLiveTags = true
    vm.journalOpeningPrompt = "Your blood pressure looked a bit high recently — any dizziness or unusual feelings today?"

    return JournalEntryView(previewViewModel: vm)
        .modelContainer(SwiftDataContainer.create(inMemory: true))
}

/// Shows the urgency alert state — Foundation Models detected red-flag language.
#Preview("Urgency Alert") {
    let vm = JournalEntryViewModel()
    vm.entryContent = "I have chest pain and difficulty breathing since this morning."
    vm.liveTagSuggestions = ["chest pain", "difficulty breathing"]
    vm.showUrgencyAlert = true
    vm.urgentKeywords = ["chest pain", "difficulty breathing"]

    return JournalEntryView(previewViewModel: vm)
        .modelContainer(SwiftDataContainer.create(inMemory: true))
}
