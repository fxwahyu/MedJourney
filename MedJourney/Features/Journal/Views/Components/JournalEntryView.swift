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

    @State private var viewModel = JournalEntryViewModel()

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

                    AppButton("Save Entry", style: .primary, icon: "checkmark", isFullWidth: true) {
                        viewModel.saveEntry(context: modelContext, dismiss: dismiss)
                    }
                }
                .padding(AppSpacing.xxl)
            }
            .background(AppColors.background)
            .navigationTitle("New Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(AppColors.brandDark)
                }
            }
            .alert("About AI Analysis", isPresented: $viewModel.showAIDisclaimer) {
                Button("I understand") { }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This AI analysis is based on uploaded documents and your existing journal entries. It is not a medical diagnosis. We strongly encourage you to discuss any findings with a qualified healthcare professional.")
            }
        }
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

    // MARK: - Journal Section

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

            AppTextArea(
                "What's on your mind?",
                text: $viewModel.entryContent,
                placeholder: "Describe what you're experiencing — any symptoms, how long it's been going on, what makes it better or worse...",
                maxCharacters: 500
            )
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

            // AI Diagnose button — appears after upload
            if !viewModel.uploadedImages.isEmpty {
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
                            Text("AI-powered analysis of your documents")
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
                .animation(.easeInOut(duration: 0.2), value: viewModel.uploadedImages.count)
            }

            AppTextArea(
                "Additional Notes",
                text: $viewModel.entryContent,
                placeholder: "Any context about your checkup, what the doctor said...",
                maxCharacters: 500
            )
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

#Preview {
    JournalEntryView()
        .modelContainer(SwiftDataContainer.create(inMemory: true))
}
