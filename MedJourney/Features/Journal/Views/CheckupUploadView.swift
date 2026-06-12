import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers

struct CheckupUploadView: View {

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel = CheckupViewModel()

    var body: some View {
        @Bindable var vm = viewModel
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.xl) {
                    heroHeader
                    sourcePickerSection($vm)
                    if !viewModel.uploadedImages.isEmpty {
                        previewSection
                    }
                    notesSection($vm)
                    if viewModel.hasContent {
                        aiSection
                    }
                    if viewModel.hasContent {
                        saveButton
                    }
                }
                .padding(.horizontal, AppSpacing.xl)
                .padding(.top, AppSpacing.lg)
                .padding(.bottom, 48)
            }
            .background(AppColors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(AppColors.brandDark)
                }
            }
            .sheet(isPresented: $vm.showCamera) {
                CameraPickerView(images: $vm.uploadedImages)
            }
            .fileImporter(
                isPresented: $vm.showFilePicker,
                allowedContentTypes: [UTType.pdf, UTType.image],
                allowsMultipleSelection: false
            ) { result in
                viewModel.handleFileImport(result: result)
            }
            .alert("About AI Analysis", isPresented: $vm.showAIDisclaimer) {
                Button("I understand") { viewModel.analyzeWithAI() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("MedCare AI reviews your documents to surface helpful observations — not diagnoses. Always discuss results with your healthcare provider before making any health decisions.")
            }
        }
    }

    // MARK: - Hero

    private var heroHeader: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .fill(LinearGradient(
                    colors: [AppColors.checkupTeal, AppColors.brandDark],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .shadow(color: AppColors.checkupTeal.opacity(0.28), radius: 20, y: 12)

            FloatingSparkles()
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))

            HStack(alignment: .top, spacing: AppSpacing.md) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Upload your results")
                        .styled(.h3)
                        .foregroundStyle(.white)
                    Text("MedCare AI reads it and builds your daily health checklist")
                        .appFont(.caption)
                        .foregroundStyle(.white.opacity(0.9))
                        .lineSpacing(3)

                    HStack(spacing: 5) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 10, weight: .bold))
                        Text("Checklist generation")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.2))
                    .clipShape(Capsule())
                    .padding(.top, AppSpacing.xs)
                }

                Spacer()

                Image(systemName: "doc.text.fill")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(AppSpacing.xl)
        }
        .frame(minHeight: 110)
    }

    // MARK: - Source Picker

    private func sourcePickerSection(_ vm: Bindable<CheckupViewModel>) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Choose source")
                .styled(.labelCaps)
                .foregroundStyle(AppColors.textTertiary)

            HStack(spacing: AppSpacing.md) {
                // Camera — clay gradient
                sourceButton(
                    icon: "camera.fill",
                    label: "Camera",
                    gradient: LinearGradient(
                        colors: [AppColors.accentOrange, Color(hex: "A85E37")],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                ) { viewModel.showCamera = true }

                // Photos — brand gradient
                PhotosPicker(
                    selection: vm.selectedPhotoItems,
                    maxSelectionCount: 5,
                    matching: .images
                ) {
                    sourceButtonLabel(
                        icon: "photo.fill",
                        label: "Photos",
                        gradient: LinearGradient(
                            colors: [AppColors.brand, AppColors.brandDark],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                }
                .buttonStyle(ScaleButtonStyle())

                // PDF / File — insights→aurora gradient
                sourceButton(
                    icon: "doc.fill",
                    label: "PDF / File",
                    gradient: LinearGradient(
                        colors: [AppColors.indigo, AppColors.sky],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                ) { viewModel.showFilePicker = true }
            }
        }
    }

    private func sourceButton(icon: String, label: String, gradient: LinearGradient, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            sourceButtonLabel(icon: icon, label: label, gradient: gradient)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func sourceButtonLabel(icon: String, label: String, gradient: LinearGradient) -> some View {
        VStack(spacing: AppSpacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .fill(gradient)
                    .aspectRatio(1, contentMode: .fit)
                    .frame(maxHeight: 66)
                    .appShadow(.card)
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.white)
            }
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Previews

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("\(viewModel.uploadedImages.count) file(s) ready")
                .appFont(.small)
                .bold()
                .foregroundStyle(AppColors.brandDark)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.sm) {
                    ForEach(viewModel.uploadedImages.indices, id: \.self) { i in
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: viewModel.uploadedImages[i])
                                .resizable()
                                .scaledToFill()
                                .frame(width: 78, height: 96)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(AppColors.border, lineWidth: 1)
                                }

                            Button { viewModel.removeImage(at: i) } label: {
                                ZStack {
                                    Circle()
                                        .fill(AppColors.error)
                                        .frame(width: 20, height: 20)
                                    Image(systemName: "xmark")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }
                            .offset(x: 6, y: -6)
                        }
                    }
                }
                .padding(.vertical, AppSpacing.xs)
            }
        }
    }

    // MARK: - Notes

    private func notesSection(_ vm: Bindable<CheckupViewModel>) -> some View {
        AppTextArea(
            "Doctor notes",
            text: vm.notes,
            placeholder: "Instructions, prescriptions, symptoms, remedies suggested…",
            maxCharacters: 600
        )
    }

    // MARK: - AI Section

    @ViewBuilder
    private var aiSection: some View {
        if viewModel.isAnalyzing {
            analyzingCard
                .transition(.opacity)
        } else if let analysis = viewModel.aiAnalysis {
            aiResultCard(analysis: analysis)
                .transition(.opacity.combined(with: .scale(scale: 0.97)))
        } else {
            analyzeButton
        }
    }

    // Idle — AuroraCard tap target
    private var analyzeButton: some View {
        Button { viewModel.showAIDisclaimer = true } label: {
            HStack(spacing: AppSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13)
                        .fill(AppColors.accentVioletPale)
                        .frame(width: 44, height: 44)
                    Image(systemName: "sparkles")
                        .font(.system(size: 20))
                        .foregroundStyle(AppColors.accentViolet)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Analyze with MedCare AI")
                        .appFont(.bodySemibold)
                        .foregroundStyle(AppColors.textPrimary)
                    Text("MedCare AI reviews your results & builds your checklist")
                        .appFont(.caption)
                        .foregroundStyle(AppColors.textTertiary)
                }
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColors.accentViolet)
            }
            .padding(AppSpacing.lg)
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        }
        .buttonStyle(ScaleButtonStyle())
        .aiGlow(cornerRadius: AppRadius.lg)
    }

    // Analyzing — AIOrbitLoader + stepped chips
    private var analyzingCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            HStack(spacing: AppSpacing.lg) {
                AIOrbitLoader(size: 42)
                VStack(alignment: .leading, spacing: 3) {
                    Text("MedCare AI is reviewing your documents…")
                        .appFont(.bodySemibold)
                        .foregroundStyle(AppColors.textPrimary)
                    Text("Reading → summarizing → building checklist")
                        .appFont(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            // Stepped chips
            HStack(spacing: AppSpacing.sm) {
                ForEach(["Reading", "Summarizing", "Building checklist"], id: \.self) { step in
                    Text(step)
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(AppColors.accentViolet)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(AppColors.accentVioletPale)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(AppSpacing.xl)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .aiGlow(cornerRadius: AppRadius.lg)
    }

    // Result — aurora card with checkupTeal tags + markdown
    private func aiResultCard(analysis: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColors.accentViolet)
                Text("MedCare AI insights")
                    .appFont(.bodySemibold)
                    .foregroundStyle(AppColors.textPrimary)
                Spacer()
                AISparkleTag(label: "AI")
            }

            if let tags = viewModel.aiTags, !tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.xs) {
                        ForEach(tags.prefix(6), id: \.self) { tag in
                            HStack(spacing: 3) {
                                Image(systemName: "tag.fill")
                                    .font(.system(size: 8))
                                Text(tag)
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundStyle(AppColors.checkupTeal)
                            .padding(.horizontal, AppSpacing.sm)
                            .padding(.vertical, 4)
                            .background(Color(hex: "E2F1F4"))
                            .clipShape(Capsule())
                        }
                    }
                }
            }

            Divider().foregroundStyle(AppColors.border)

            MarkdownAnalysisView(markdown: analysis)
        }
        .padding(AppSpacing.lg)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .aiGlow(cornerRadius: AppRadius.lg)
    }

    // MARK: - Save Button

    private var saveButton: some View {
        VStack(spacing: AppSpacing.sm) {
            Button {
                viewModel.saveEntry(context: context) { dismiss() }
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    if viewModel.isSaving {
                        ProgressView().tint(.white).scaleEffect(0.85)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                    }
                    Text(viewModel.isSaving ? "Saving…" : "Save & generate daily checklist")
                        .appFont(.button)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.md)
                .background(AppGradients.aiGlow)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                .appShadow(.elevated)
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(viewModel.isSaving)

            Text("MedCare AI will refresh your home checklist from these results")
                .appFont(.small)
                .foregroundStyle(AppColors.textTertiary)
                .multilineTextAlignment(.center)
        }
    }
}

#Preview {
    CheckupUploadView()
        .modelContainer(SwiftDataContainer.create(inMemory: true))
}
