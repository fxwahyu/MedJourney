import SwiftUI
import SwiftData

struct ExportPreviewView: View {
    let entries: [JournalEntry]
    let medicines: [Medicine]

    @State private var isRendering = false
    @State private var exportedImage: UIImage?
    @State private var showShareSheet = false
    @Environment(\.dismiss) private var dismiss

    /// Entries sorted oldest → newest for the doctor's timeline view
    private var timeline: [JournalEntry] {
        entries.sorted { $0.createdAt < $1.createdAt }
    }

    private var dateRange: String {
        guard let first = timeline.first?.createdAt,
              let last = timeline.last?.createdAt else { return "No entries" }
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        return "\(fmt.string(from: first)) – \(fmt.string(from: last))"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "2A302E").ignoresSafeArea()

                ScrollView {
                    VStack(spacing: AppSpacing.xl) {
                        documentCard
                            .padding(.horizontal, AppSpacing.lg)
                            .padding(.top, AppSpacing.xl)

                        actionRow
                            .padding(.horizontal, AppSpacing.lg)
                            .padding(.bottom, 60)
                    }
                }
            }
            .navigationTitle("Health Journal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let image = exportedImage {
                    ShareSheet(activityItems: [image])
                }
            }
        }
    }

    // MARK: - Document card

    private var documentCard: some View {
        VStack(spacing: 0) {
            // Cover band
            coverBand

            // Timeline body
            VStack(alignment: .leading, spacing: AppSpacing.xl) {
                // Medications in use
                if !medicines.isEmpty {
                    medicationsSection
                    Divider().foregroundStyle(AppColors.border)
                }

                // Daily timeline
                if timeline.isEmpty {
                    Text("No entries to display.")
                        .appFont(.body)
                        .foregroundStyle(AppColors.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, AppSpacing.xl)
                } else {
                    timelineSection
                }

                // Disclaimer
                Text("This document summarizes self-reported data from the MedJourney app. It is not a medical diagnosis. Generated on \(Date().formatted(date: .abbreviated, time: .omitted)).")
                    .font(.system(size: 9.5))
                    .foregroundStyle(AppColors.textTertiary)
                    .lineSpacing(3)
                    .padding(.top, AppSpacing.xs)
            }
            .padding(AppSpacing.xl)
            .background(AppColors.surface)
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .shadow(color: .black.opacity(0.4), radius: 24, y: 12)
    }

    // MARK: - Cover band

    private var coverBand: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // Brand mark
            HStack(spacing: AppSpacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 28, height: 28)
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }
                Text("MedJourney")
                    .styled(.h3)
                    .foregroundStyle(.white.opacity(0.9))
                Spacer()
            }

            Spacer().frame(height: AppSpacing.md)

            Text("Personal Health Journal")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.4)
                .textCase(.uppercase)
                .foregroundStyle(.white.opacity(0.8))

            Text("Wahyu Herdianto")
                .styled(.h2)
                .foregroundStyle(.white)

            Text(dateRange)
                .appFont(.caption)
                .foregroundStyle(.white.opacity(0.85))

            Text("Prepared for Dr. Reyes")
                .appFont(.small)
                .foregroundStyle(.white.opacity(0.65))
        }
        .padding(AppSpacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppGradients.header)
    }

    // MARK: - Medications section

    private var medicationsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            sectionLabel("Medications")
            ForEach(medicines) { med in
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "pills.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.rose)
                    Text(med.name)
                        .appFont(.bodySemibold)
                        .foregroundStyle(AppColors.textPrimary)
                    if !med.notes.isEmpty {
                        Text("· \(med.notes)")
                            .appFont(.caption)
                            .foregroundStyle(AppColors.textTertiary)
                            .lineLimit(1)
                    }
                    Spacer()
                    if !med.notificationTimes.isEmpty {
                        Text(med.notificationTimes.joined(separator: ", "))
                            .font(.custom("DMMono-Medium", size: 11))
                            .foregroundStyle(AppColors.textTertiary)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: - Timeline section

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("Health Timeline")
                .padding(.bottom, AppSpacing.md)

            ForEach(Array(timeline.enumerated()), id: \.element.id) { idx, entry in
                timelineRow(entry: entry, isLast: idx == timeline.count - 1)
            }
        }
    }

    private func timelineRow(entry: JournalEntry, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            // Left column: date + connector line
            VStack(spacing: 0) {
                Text(entry.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.custom("DMMono-Medium", size: 10))
                    .foregroundStyle(AppColors.textTertiary)
                    .frame(width: 68, alignment: .leading)
                    .padding(.top, 2)
                if !isLast {
                    Rectangle()
                        .fill(AppColors.border)
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                        .padding(.top, 6)
                        .padding(.leading, 5)
                }
            }
            .frame(width: 68)

            // Dot
            Circle()
                .fill(entryColor(entry))
                .frame(width: 8, height: 8)
                .padding(.top, 5)

            // Content
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                // Type + title
                HStack(spacing: AppSpacing.xs) {
                    Text(entry.entryType.displayName.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(entryColor(entry))
                    Text("·")
                        .appFont(.small)
                        .foregroundStyle(AppColors.textTertiary)
                    Text(entry.createdAt.formatted(date: .omitted, time: .shortened))
                        .font(.custom("DMMono-Medium", size: 10))
                        .foregroundStyle(AppColors.textTertiary)
                }

                Text(entry.title)
                    .appFont(.bodySemibold)
                    .foregroundStyle(AppColors.textPrimary)

                if !entry.content.isEmpty {
                    Text(entry.content)
                        .appFont(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(3)
                        .lineSpacing(2)
                }

                // Vitals
                if hasVitals(entry) {
                    HStack(spacing: AppSpacing.md) {
                        if let bp = entry.bloodPressure, !bp.isEmpty {
                            vitalPill("drop.fill", bp, "mmHg")
                        }
                        if let hr = entry.heartRate {
                            vitalPill("waveform.path.ecg", "\(hr)", "bpm")
                        }
                        if let temp = entry.temperature {
                            vitalPill("thermometer.medium", String(format: "%.1f", temp), "°C")
                        }
                        if let weight = entry.weight {
                            vitalPill("scalemass", String(format: "%.1f", weight), "kg")
                        }
                    }
                }
            }
            .padding(.bottom, isLast ? 0 : AppSpacing.xl)
        }
    }

    private func vitalPill(_ icon: String, _ value: String, _ unit: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundStyle(AppColors.textTertiary)
            Text(value)
                .font(.custom("DMMono-Medium", size: 11))
                .foregroundStyle(AppColors.textPrimary)
            Text(unit)
                .font(.system(size: 9))
                .foregroundStyle(AppColors.textTertiary)
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .tracking(1.0)
            .textCase(.uppercase)
            .foregroundStyle(AppColors.brandDark)
    }

    private func hasVitals(_ entry: JournalEntry) -> Bool {
        (entry.bloodPressure != nil && !(entry.bloodPressure?.isEmpty ?? true))
        || entry.heartRate != nil
        || entry.temperature != nil
        || entry.weight != nil
    }

    private func entryColor(_ entry: JournalEntry) -> Color {
        switch entry.entryType {
        case .journal:    return AppColors.brand
        case .checkup:    return AppColors.checkupTeal
        case .medication: return AppColors.rose
        }
    }

    // MARK: - Action row

    private var actionRow: some View {
        HStack(spacing: AppSpacing.md) {
            Button {
                renderAndShare()
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    if isRendering {
                        ProgressView().tint(.white).scaleEffect(0.85)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    Text(isRendering ? "Preparing…" : "Share PDF")
                        .appFont(.button)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.md)
                .background(AppColors.brand)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                .appShadow(.elevated)
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(isRendering)
        }
    }

    // MARK: - Render

    private func renderAndShare() {
        isRendering = true
        Task {
            let renderer = ImageRenderer(content:
                documentCard
                    .frame(width: 360)
                    .padding(AppSpacing.lg)
                    .background(Color(hex: "2A302E"))
                    .environment(\.colorScheme, .light)
            )
            renderer.scale = UIScreen.main.scale
            exportedImage = renderer.uiImage
            isRendering = false
            showShareSheet = true
        }
    }
}

// MARK: - Share sheet wrapper

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}

#Preview {
    ExportPreviewView(entries: [], medicines: [])
}
