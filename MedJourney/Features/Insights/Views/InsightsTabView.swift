import SwiftUI
import SwiftData
import Charts

struct InsightsTabView: View {

    @Query(sort: \JournalEntry.createdAt, order: .reverse)  private var entries: [JournalEntry]
    @Query(sort: \ChecklistItem.sortOrder)                  private var checklistItems: [ChecklistItem]
    @Query(filter: #Predicate<Medicine> { $0.isActive })    private var activeMedicines: [Medicine]

    @State private var viewModel = InsightsViewModel()
    @State private var showExport = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    header
                    VStack(spacing: AppSpacing.lg) {
                        statsRow
                        streakAndCompletionRow
                        if !viewModel.moodPoints.isEmpty {
                            moodTrendCard
                        }
                        if !viewModel.vitalsData.isEmpty {
                            vitalsTrendCard
                        }
                        if !viewModel.anomalies.isEmpty {
                            anomalyBannerCard
                        }
                        tagFrequencyCard
//                        if !viewModel.medicationCorrelations.isEmpty {
//                            medicationCorrelationCard
//                        }
                        aiSummaryCard
                        exportRow
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.top, AppSpacing.xl)
                    .padding(.bottom, 120)
                }
            }
            .ignoresSafeArea(edges: .top)
            .background(AppColors.background)
            .navigationBarHidden(true)
            .onAppear { reloadViewModel() }
            .onChange(of: entries.count)         { _, _ in reloadViewModel() }
            .onChange(of: checklistItems.count)  { _, _ in reloadViewModel() }
            .onChange(of: activeMedicines.count) { _, _ in reloadViewModel() }
            .sheet(isPresented: $showExport) {
                ExportPreviewView(entries: entries, medicines: Array(activeMedicines))
            }
        }
    }

    private func reloadViewModel() {
        viewModel.loadData(from: entries, checklistItems: checklistItems, medicines: activeMedicines)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Spacer().frame(height: 56)
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("AI Insights")
                        .styled(.labelCaps)
                        .foregroundStyle(AppColors.textTertiary)
                    Text("Health overview")
                        .styled(.h1)
                        .foregroundStyle(AppColors.textPrimary)
                    Text("Based on \(entries.count) entries")
                        .appFont(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
                Spacer()
                AISparkleTag()
                    .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppSpacing.xxl)
        .padding(.bottom, AppSpacing.xl)
        .background {
            LinearGradient(
                colors: [AppColors.indigo.opacity(0.35), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)
        }
        .overlay(alignment: .bottom) {
            Divider().opacity(0.25)
        }
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: AppSpacing.md) {
            statChip(
                icon: "heart.text.square.fill",
                value: "\(entries.filter { $0.entryType == .journal }.count)",
                label: "Journal",
                gradient: AppGradients.header
            )
            statChip(
                icon: "doc.text.fill",
                value: "\(entries.filter { $0.entryType == .checkup }.count)",
                label: "Checkups",
                gradient: AppGradients.checkup
            )
            statChip(
                icon: "tag.fill",
                value: "\(viewModel.tagCounts.count)",
                label: "Symptoms",
                gradient: AppGradients.insights
            )
        }
    }

    private func statChip(icon: String, value: String, label: String, gradient: LinearGradient) -> some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(.white)
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.lg)
        .background(gradient)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
    }

    // MARK: - Streak & Completion Row

    private var streakAndCompletionRow: some View {
        HStack(spacing: AppSpacing.md) {
            miniStatCard(
                icon: "flame.fill",
                value: "\(viewModel.journalStreak)",
                label: "day streak",
                color: AppColors.accentOrange
            )
            miniStatCard(
                icon: "checkmark.circle.fill",
                value: viewModel.checklistCompletionRate.map { "\(Int($0 * 100))%" } ?? "--",
                label: "checklist avg",
                color: AppColors.brand
            )
        }
    }

    private func miniStatCard(icon: String, value: String, label: String, color: Color) -> some View {
        HStack(spacing: AppSpacing.md) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary)
                Text(label)
                    .font(.system(size: 11))
                    .foregroundStyle(AppColors.textTertiary)
            }
            Spacer()
        }
        .padding(AppSpacing.lg)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.border, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }

    // MARK: - Mood Trend Chart

    private var moodTrendCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mood Trend")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppColors.textPrimary)
                    Text("Last 30 days")
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.textTertiary)
                }
                Spacer()
                moodLegend
            }

            Chart(viewModel.moodPoints) { point in
                AreaMark(x: .value("Date", point.date), y: .value("Score", point.score))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppColors.brand.opacity(0.35), AppColors.brand.opacity(0.05)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                LineMark(x: .value("Date", point.date), y: .value("Score", point.score))
                    .foregroundStyle(AppColors.brand)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                    .interpolationMethod(.catmullRom)
                PointMark(x: .value("Date", point.date), y: .value("Score", point.score))
                    .foregroundStyle(AppColors.brandDark)
                    .symbolSize(40)
            }
            .chartYScale(domain: 0...6)
            .chartYAxis {
                AxisMarks(values: [0, 2, 4, 6]) { val in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(AppColors.border)
                    AxisValueLabel {
                        if let idx = val.as(Int.self) {
                            let labels = ["Pain", "", "Anxious", "", "Good", "", "Great"]
                            Text(idx < labels.count ? labels[idx] : "")
                                .font(.system(size: 9)).foregroundStyle(AppColors.textTertiary)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                    AxisGridLine().foregroundStyle(AppColors.border)
                    AxisValueLabel(format: .dateTime.day().month())
                        .font(.system(size: 9)).foregroundStyle(AppColors.textTertiary)
                }
            }
            .frame(height: 180)
        }
        .padding(AppSpacing.xl)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl))
        .shadow(color: AppColors.brand.opacity(0.08), radius: 12, x: 0, y: 4)
    }

    private var moodLegend: some View {
        HStack(spacing: AppSpacing.xs) {
            if let latest = viewModel.moodPoints.last {
                Text(JournalMood.allCases.first { $0.score == Int(latest.score) }?.emoji ?? "")
                    .font(.system(size: 18))
                Text("Latest")
                    .font(.system(size: 11))
                    .foregroundStyle(AppColors.textTertiary)
            }
        }
    }

    // MARK: - Vitals Trend Chart

    private var vitalsTrendCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Vitals Trend")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppColors.textPrimary)
                    Text("Personal baseline — \(viewModel.selectedPeriod.label.lowercased())")
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.textTertiary)
                }
                Spacer()
            }

            // Type picker — only show types that have data
            let availableTypes = InsightsViewModel.VitalDisplayType.allCases.filter {
                viewModel.vitalsData[$0] != nil
            }
            if availableTypes.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.sm) {
                        ForEach(availableTypes, id: \.self) { type in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    viewModel.selectedVitalType = type
                                }
                            } label: {
                                Text(type.rawValue)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(
                                        viewModel.selectedVitalType == type
                                            ? type.accentColor
                                            : AppColors.textTertiary
                                    )
                                    .padding(.horizontal, AppSpacing.md)
                                    .padding(.vertical, 6)
                                    .background(
                                        viewModel.selectedVitalType == type
                                            ? type.accentColor.opacity(0.1)
                                            : AppColors.surface2
                                    )
                                    .clipShape(Capsule())
                                    .overlay {
                                        Capsule().stroke(
                                            viewModel.selectedVitalType == type
                                                ? type.accentColor.opacity(0.4)
                                                : Color.clear,
                                            lineWidth: 1
                                        )
                                    }
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                    }
                }
            }

            if let points = viewModel.vitalsData[viewModel.selectedVitalType], !points.isEmpty {
                let accentColor = viewModel.selectedVitalType.accentColor
                let unit        = viewModel.selectedVitalType.unit

                Chart(points) { point in
                    AreaMark(x: .value("Date", point.date), y: .value("Value", point.value))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [accentColor.opacity(0.25), accentColor.opacity(0.02)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                    LineMark(x: .value("Date", point.date), y: .value("Value", point.value))
                        .foregroundStyle(accentColor)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                        .interpolationMethod(.catmullRom)
                    PointMark(x: .value("Date", point.date), y: .value("Value", point.value))
                        .foregroundStyle(accentColor)
                        .symbolSize(36)
                }
                .chartYAxis {
                    AxisMarks { val in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(AppColors.border)
                        AxisValueLabel {
                            if let v = val.as(Double.self) {
                                Text("\(Int(v)) \(unit)")
                                    .font(.system(size: 9)).foregroundStyle(AppColors.textTertiary)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine().foregroundStyle(AppColors.border)
                        AxisValueLabel(format: .dateTime.day().month())
                            .font(.system(size: 9)).foregroundStyle(AppColors.textTertiary)
                    }
                }
                .frame(height: 160)
                .animation(.easeInOut(duration: 0.3), value: viewModel.selectedVitalType)
            }
        }
        .padding(AppSpacing.xl)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl))
        .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 4)
    }

    // MARK: - Anomaly Banner

    private var anomalyBannerCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppColors.error)
                Text("Anomali Detected")
                    .appFont(.bodySemibold)
                    .foregroundStyle(AppColors.error)
                Spacer()
            }

            ForEach(viewModel.anomalies.prefix(3)) { anomaly in
                HStack(alignment: .top, spacing: AppSpacing.sm) {
                    Circle()
                        .fill(AppColors.error)
                        .frame(width: 6, height: 6)
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

    // MARK: - Export Row

    private var exportRow: some View {
        Button {
            showExport = true
        } label: {
            HStack(spacing: AppSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppRadius.sm)
                        .fill(AppColors.brandPale)
                        .frame(width: 44, height: 44)
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(AppColors.brandDark)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Export Health Journal")
                        .appFont(.bodySemibold)
                        .foregroundStyle(AppColors.textPrimary)
                    Text("Generate a shareable PDF report")
                        .appFont(.caption)
                        .foregroundStyle(AppColors.textTertiary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.textTertiary)
            }
            .padding(AppSpacing.lg)
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .stroke(AppColors.border, lineWidth: 1)
            }
            .appShadow(.card)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Tag Frequency Chart

    private var tagFrequencyCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Symptom Frequency")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppColors.textPrimary)
                    Text("Top tags from your entries")
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.textTertiary)
                }
                Spacer()
            }

            // Period picker
            Picker("Period", selection: $viewModel.selectedPeriod) {
                ForEach(InsightsViewModel.InsightPeriod.allCases, id: \.self) { period in
                    Text(period.label).tag(period)
                }
            }
            .pickerStyle(.segmented)

            if viewModel.tagCounts.isEmpty {
                Text("No symptom tags yet for this period.")
                    .font(.system(size: 13))
                    .foregroundStyle(AppColors.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, AppSpacing.lg)
            } else {
                Chart(viewModel.tagCounts.prefix(8)) { item in
                    BarMark(x: .value("Count", item.count), y: .value("Tag", item.tag))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppColors.accentViolet, AppColors.sky, AppColors.aiCyan],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .cornerRadius(4)
                        .annotation(position: .trailing) {
                            Text("\(item.count)")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(AppColors.textTertiary)
                        }
                }
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks { val in
                        AxisValueLabel()
                            .font(.system(size: 11))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
                .frame(height: CGFloat(min(viewModel.tagCounts.count, 8)) * 36 + 20)
            }

            // On-device AI insight (Foundation Models phrases the stats locally)
            if viewModel.isLoadingInsight {
                HStack(spacing: AppSpacing.sm) {
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(AppColors.accentViolet)
                    Text("Generating insight…")
                        .appFont(.caption)
                        .foregroundStyle(AppColors.textTertiary)
                }
            } else if let insight = viewModel.onDeviceInsight {
                HStack(alignment: .top, spacing: AppSpacing.sm) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppColors.accentViolet)
                        .padding(.top, 2)
                    Text(insight)
                        .appFont(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                        .lineSpacing(3)
                        .italic()
                }
                .padding(.top, AppSpacing.xs)
            }
        }
        .padding(AppSpacing.xl)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl))
        .shadow(color: AppColors.accentViolet.opacity(0.1), radius: 12, x: 0, y: 4)
    }

    // MARK: - Medication Correlation Card

    private var medicationCorrelationCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Medication Impact")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppColors.textPrimary)
                    Text("Symptom count before vs. after starting")
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.textTertiary)
                }
                Spacer()
            }

            VStack(spacing: AppSpacing.md) {
                ForEach(viewModel.medicationCorrelations) { correlation in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(correlation.medicationName)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(AppColors.textPrimary)
                            Text("Since \(correlation.startDate.formatted(date: .abbreviated, time: .omitted))")
                                .font(.system(size: 11))
                                .foregroundStyle(AppColors.textTertiary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(correlation.trendLabel)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(correlation.trendColor)
                            if let pct = correlation.changePercent {
                                Text("\(pct > 0 ? "+" : "")\(Int(pct))% symptoms")
                                    .font(.system(size: 11))
                                    .foregroundStyle(AppColors.textTertiary)
                            }
                        }
                    }
                    .padding(AppSpacing.md)
                    .background(AppColors.surface2)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                }
            }
        }
        .padding(AppSpacing.xl)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.xl)
                .stroke(AppColors.border, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 4)
    }

    // MARK: - AI Summary Card

    private var aiSummaryCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            // Header row
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("MedCare AI Summary")
                        .appFont(.bodySemibold)
                        .foregroundStyle(AppColors.textPrimary)
                    Text("Your personal health summary, on demand")
                        .appFont(.caption)
                        .foregroundStyle(AppColors.textTertiary)
                }
                Spacer()
                AISparkleTag()
            }

            // Generated-on timestamp — shown whenever a summary exists
            if let date = viewModel.summaryGeneratedDate {
                HStack(spacing: 5) {
                    Image(systemName: "clock")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AppColors.accentViolet.opacity(0.7))
                    Text("Last generated: \(summaryDateString(date))")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppColors.accentViolet.opacity(0.8))
                }
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, 5)
                .background(AppColors.accentVioletPale)
                .clipShape(Capsule())
            }

            // Content states
            if viewModel.isGeneratingSummary {
                AILoadingBanner(message: "MedCare AI is reviewing your health patterns…")
            } else if let summary = viewModel.healthSummary {
                aiSummaryContent(summary)
            } else if let error = viewModel.summaryError {
                VStack(spacing: AppSpacing.sm) {
                    Text(error)
                        .appFont(.caption)
                        .foregroundStyle(AppColors.error)
                    Button("Retry") { viewModel.generateDeepSummary() }
                        .appFont(.caption)
                        .foregroundStyle(AppColors.brandDark)
                }
            } else {
                generateButton
            }
        }
        .padding(AppSpacing.xl)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl))
        .aiGlow(cornerRadius: AppRadius.xl)
    }

    /// Formats the generation date clearly:
    /// - Same day  → "Today at 2:30 PM"
    /// - Yesterday → "Yesterday at 2:30 PM"
    /// - Older     → "Jun 6 at 2:30 PM"
    private func summaryDateString(_ date: Date) -> String {
        let calendar = Calendar.current
        let timeStr = date.formatted(date: .omitted, time: .shortened)
        if calendar.isDateInToday(date) {
            return "Today at \(timeStr)"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday at \(timeStr)"
        } else {
            let dateStr = date.formatted(.dateTime.month(.abbreviated).day())
            return "\(dateStr) at \(timeStr)"
        }
    }

    private var generateButton: some View {
        Button {
            viewModel.generateDeepSummary()
        } label: {
            HStack(spacing: AppSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppRadius.sm)
                        .fill(AppColors.accentVioletPale)
                        .frame(width: 52, height: 52)
                    Image(systemName: "wand.and.sparkles")
                        .font(.system(size: 22))
                        .foregroundStyle(AppColors.accentViolet)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Generate my MedCare AI summary")
                        .appFont(.bodySemibold)
                        .foregroundStyle(AppColors.textPrimary)
                    Text("MedCare AI reviews your patterns, not your raw entries")
                        .appFont(.caption)
                        .foregroundStyle(AppColors.textTertiary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColors.accentViolet)
            }
            .padding(AppSpacing.lg)
            .background(AppColors.accentVioletPale.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(entries.isEmpty)
    }

    private func aiSummaryContent(_ summary: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            MarkdownAnalysisView(markdown: summary)
            Divider().foregroundStyle(AppColors.border)
            Button {
                viewModel.generateDeepSummary()
            } label: {
                HStack(spacing: AppSpacing.xs) {
                    if viewModel.isGeneratingSummary {
                        ProgressView().scaleEffect(0.7).tint(AppColors.accentViolet)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    Text(viewModel.isGeneratingSummary ? "Refreshing…" : "Refresh analysis")
                        .appFont(.caption)
                        .bold()
                }
                .foregroundStyle(AppColors.accentViolet)
            }
            .disabled(viewModel.isGeneratingSummary)
        }
    }
}

#Preview {
    InsightsTabView()
        .modelContainer(SwiftDataContainer.create(inMemory: true))
}
