//
//  JournalEntryDetailView.swift
//  MedJourney
//
//  Feature: Journal — Read-only detail sheet matching the Vital Calm "EntryDetail" prototype.
//

import SwiftUI

struct JournalEntryDetailView: View {

    let entry: JournalEntry
    @Environment(\.dismiss) private var dismiss

    @State private var isGeneratingTags = false
    private let tagService = GeminiTagService(apiKey: AIConfig.llmAPIKey)

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    entryHeader
                    bodyText
                    if hasVitals { vitalsGrid }
                    if entry.entryType != .medication { tagsSection }
                    if let analysis = entry.aiAnalysis { aiAnalysisCard(analysis) }
                    if let imagesData = entry.attachedImagesData, !imagesData.isEmpty {
                        attachedImages(imagesData)
                    }
                }
                .padding(AppSpacing.xl)
            }
            .background(AppColors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(AppColors.brandDark)
                }
            }
        }
    }

    // MARK: - Header: tile + serif title + date

    private var entryHeader: some View {
        HStack(spacing: AppSpacing.md) {
            // 52px rounded tile — prototype: width 52, borderRadius 16, category pale
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(typePaleColor)
                    .frame(width: 52, height: 52)
                if let mood = entryMood {
                    Text(mood.emoji)
                        .font(.system(size: 28))
                } else {
                    Image(systemName: typeIcon)
                        .font(.system(size: 24, weight: .light))
                        .foregroundStyle(typeColor)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                // Serif title — prototype: fontSize 20 fontWeight 600
                Text(entry.title)
                    .styled(.h2)
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(2)

                // Date — prototype: fontSize 12.5 ink-3
                Text(entry.createdAt.formatted(date: .long, time: .shortened))
                    .appFont(.caption)
                    .foregroundStyle(AppColors.textTertiary)
            }
        }
    }

    // MARK: - Body text

    @ViewBuilder
    private var bodyText: some View {
        if !entry.content.isEmpty {
            Text(entry.content)
                .appFont(.bodyLarge)
                .foregroundStyle(AppColors.textSecondary)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Vitals 2×2 grid

    private var hasVitals: Bool {
        entry.bloodPressure != nil || entry.heartRate != nil
        || entry.temperature != nil || entry.weight != nil
    }

    private var vitalsGrid: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: AppSpacing.sm), GridItem(.flexible(), spacing: AppSpacing.sm)],
                spacing: AppSpacing.sm
            ) {
                if let bp = entry.bloodPressure, !bp.isEmpty {
                    vitalCell(icon: "drop.fill", label: "Blood pressure", value: bp, unit: "mmHg")
                }
                if let hr = entry.heartRate {
                    vitalCell(icon: "waveform.path.ecg", label: "Heart rate", value: "\(hr)", unit: "bpm")
                }
                if let temp = entry.temperature {
                    vitalCell(icon: "thermometer.medium", label: "Temperature", value: String(format: "%.1f", temp), unit: "°C")
                }
                if let weight = entry.weight {
                    vitalCell(icon: "scalemass", label: "Weight", value: String(format: "%.1f", weight), unit: "kg")
                }
            }
        }
        .padding(AppSpacing.lg)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.md)
                .stroke(AppColors.border, lineWidth: 1)
        }
    }

    private func vitalCell(icon: String, label: String, value: String, unit: String) -> some View {
        HStack(spacing: AppSpacing.sm) {
            // 36px brandPale tile — prototype
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(AppColors.brandPale)
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppColors.brand)
            }
            VStack(alignment: .leading, spacing: 2) {
                // Mono value — prototype: className="mono" fontSize 16
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(value)
                        .font(.custom("DMMono-Medium", size: 16))
                        .foregroundStyle(AppColors.textPrimary)
                    Text(unit)
                        .appFont(.small)
                        .foregroundStyle(AppColors.textTertiary)
                }
                Text(label)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(AppColors.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Tags section

    @ViewBuilder
    private var tagsSection: some View {
        if !entry.aiTags.isEmpty {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack {
                    Text("Detected symptoms")
                        .styled(.labelCaps)
                        .foregroundStyle(AppColors.textTertiary)
                    Spacer()
                    AISparkleTag(label: "AI tags")
                }
                FlowLayout(tags: entry.aiTags, color: tagColor, bgColor: tagBgColor)
            }
        } else if entry.entryType == .checkup {
            // Generate button for unanalyzed checkups
            Button { generateTags() } label: {
                HStack(spacing: AppSpacing.sm) {
                    if isGeneratingTags {
                        AIOrbitLoader(size: 28)
                        Text("Analyzing…")
                            .appFont(.bodySemibold)
                            .foregroundStyle(AppColors.textPrimary)
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(AppColors.accentVioletPale)
                                .frame(width: 40, height: 40)
                            Image(systemName: "sparkles")
                                .font(.system(size: 18))
                                .foregroundStyle(AppColors.accentViolet)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Analyze with MedCare AI")
                                .appFont(.bodySemibold)
                                .foregroundStyle(AppColors.textPrimary)
                            Text("MedCare AI is ready to help")
                                .appFont(.caption)
                                .foregroundStyle(AppColors.textTertiary)
                        }
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppColors.accentViolet)
                    }
                }
                .padding(AppSpacing.lg)
                .background(AppColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
            }
            .disabled(isGeneratingTags)
            .buttonStyle(ScaleButtonStyle())
            .aiGlow(cornerRadius: AppRadius.md)
        } else {
            // Journal tags generating shimmer
            HStack(spacing: AppSpacing.xs) {
                skeletonPill(60); skeletonPill(80); skeletonPill(55)
            }
        }
    }

    private func skeletonPill(_ w: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: AppRadius.pill)
            .fill(AppColors.surface2)
            .frame(width: w, height: 26)
    }

    private func generateTags() {
        isGeneratingTags = true
        Task.detached(priority: .userInitiated) {
            var ocrText: String? = nil
            if let imagesData = entry.attachedImagesData {
                let images = imagesData.compactMap { UIImage(data: $0) }
                ocrText = try? await DocumentScannerService().extractText(from: images)
            }
            guard let result = try? await tagService.generateTags(for: entry, ocrText: ocrText),
                  !result.tags.isEmpty else {
                await MainActor.run { isGeneratingTags = false }
                return
            }
            await MainActor.run {
                entry.aiTags    = result.tags
                entry.aiAnalysis = result.analysis
                entry.updatedAt  = Date()
                isGeneratingTags = false
            }
        }
    }

    // MARK: - AI Analysis aurora card

    private func aiAnalysisCard(_ analysis: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColors.accentViolet)
                Text("MedCare AI insights")
                    .appFont(.bodySemibold)
                    .foregroundStyle(AppColors.textPrimary)
            }
            MarkdownAnalysisView(markdown: analysis)
        }
        .padding(AppSpacing.lg)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .aiGlow(cornerRadius: AppRadius.lg)
    }

    // MARK: - Attached images

    private func attachedImages(_ data: [Data]) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Attached documents")
                .styled(.labelCaps)
                .foregroundStyle(AppColors.textTertiary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.md) {
                    ForEach(data, id: \.self) { d in
                        if let img = UIImage(data: d) {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 120, height: 160)
                                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Type helpers

    private var entryMood: JournalMood? {
        guard entry.entryType == .journal else { return nil }
        return JournalMood.allCases.first { $0.rawValue == entry.title }
            ?? JournalMood.allCases.first { entry.title.lowercased().contains($0.rawValue.lowercased()) }
    }

    private var typeColor: Color {
        switch entry.entryType {
        case .journal:    return AppColors.brand
        case .checkup:    return AppColors.checkupTeal
        case .medication: return AppColors.rose
        }
    }

    private var typePaleColor: Color {
        switch entry.entryType {
        case .journal:    return AppColors.brandPale
        case .checkup:    return Color(hex: "E2F1F4")
        case .medication: return AppColors.rosePale
        }
    }

    private var typeIcon: String {
        switch entry.entryType {
        case .journal:    return "heart.fill"
        case .checkup:    return "doc.text.fill"
        case .medication: return "pills.fill"
        }
    }

    private var tagColor: Color {
        entry.entryType == .checkup ? AppColors.checkupTeal : AppColors.brandDark
    }

    private var tagBgColor: Color {
        entry.entryType == .checkup ? Color(hex: "E2F1F4") : AppColors.brandPale
    }
}

// MARK: - Flow layout for tags

private struct FlowLayout: View {
    let tags: [String]
    let color: Color
    let bgColor: Color

    var body: some View {
        // Simple wrapping row using ViewThatFits fallback
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.xs) {
                ForEach(tags, id: \.self) { tag in
                    HStack(spacing: 3) {
                        Image(systemName: "tag.fill")
                            .font(.system(size: 8))
                        Text(tag)
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(color)
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, 5)
                    .background(bgColor)
                    .clipShape(Capsule())
                }
            }
        }
    }
}

#Preview {
    JournalEntryDetailView(entry: JournalEntry(
        title: "Feeling tired",
        content: "I've had a headache since I woke up this morning. Dull pain at the back of my head, worsened after screen time.",
        entryType: .journal,
        bloodPressure: "132/86",
        heartRate: 88,
        temperature: 37.1
    ))
}
