import SwiftUI
import SwiftData

@Observable
final class InsightsViewModel {

    // MARK: - Nested Types

    struct MoodPoint: Identifiable {
        let id = UUID()
        let date: Date
        let score: Double
        let label: String
    }

    struct TagCount: Identifiable {
        let id = UUID()
        let tag: String
        let count: Int
    }

    struct VitalDataPoint: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
    }

    /// Period filter used throughout the Insights screen.
    enum InsightPeriod: Int, CaseIterable {
        case week    = 7
        case month   = 30
        case quarter = 90

        var label: String {
            switch self {
            case .week:    return "7 Days"
            case .month:   return "30 Days"
            case .quarter: return "90 Days"
            }
        }

        var shortLabel: String {
            switch self {
            case .week:    return "7d"
            case .month:   return "30d"
            case .quarter: return "90d"
            }
        }

        /// Maps to the AI pipeline's `InsightTimeRange` so `generateDeepSummary()`
        /// can request the matching window from the curated MD knowledge base.
        var insightTimeRange: InsightTimeRange {
            switch self {
            case .week:    return .sevenDays
            case .month:   return .thirtyDays
            case .quarter: return .custom(DateInterval(start: Date().addingTimeInterval(-90 * 86_400), end: Date()))
            }
        }
    }

    /// Which vital type to display on the vitals trend chart.
    enum VitalDisplayType: String, CaseIterable {
        case systolicBP  = "Systolic BP"
        case heartRate   = "Heart Rate"
        case temperature = "Temperature"
        case weight      = "Weight"

        var unit: String {
            switch self {
            case .systolicBP:  return "mmHg"
            case .heartRate:   return "bpm"
            case .temperature: return "°C"
            case .weight:      return "kg"
            }
        }

        var accentColor: Color {
            switch self {
            case .systolicBP:  return AppColors.error
            case .heartRate:   return AppColors.accentOrange
            case .temperature: return AppColors.amber
            case .weight:      return AppColors.brand
            }
        }
    }

    /// Symptom frequency comparison before and after a medication start date.
    struct MedicationCorrelation: Identifiable {
        let id = UUID()
        let medicationName: String
        let startDate: Date
        let tagCountBefore: Int   // 30-day window before start
        let tagCountAfter: Int    // 30-day window after start (up to today)

        var changePercent: Double? {
            guard tagCountBefore > 0 else { return nil }
            return Double(tagCountAfter - tagCountBefore) / Double(tagCountBefore) * 100.0
        }

        var trendLabel: String {
            guard let pct = changePercent else { return "Insufficient data" }
            if pct < -10 { return "Improving" }
            if pct >  10 { return "More symptoms" }
            return "Stable"
        }

        var trendColor: Color {
            guard let pct = changePercent else { return AppColors.textTertiary }
            if pct < -10 { return AppColors.brand }
            if pct >  10 { return AppColors.error }
            return AppColors.textSecondary
        }
    }

    // MARK: - Observable State

    var moodPoints: [MoodPoint] = []
    var tagCounts: [TagCount] = []

    // Period filter — changing it triggers a reload of period-sensitive data
    var selectedPeriod: InsightPeriod = .month {
        didSet { reloadPeriodData() }
    }

    // Vitals trend chart
    var vitalsData: [VitalDisplayType: [VitalDataPoint]] = [:]
    var selectedVitalType: VitalDisplayType = .systolicBP

    // Quick stats
    var journalStreak: Int = 0
    var checklistCompletionRate: Double? = nil

    // Medication correlation
    var medicationCorrelations: [MedicationCorrelation] = []

    // Anomalies — sourced from VitalsAnomalyDetector (on-device)
    var anomalies: [VitalsAnomaly] = []

    // On-device insight (Foundation Models phrases the local stats)
    var onDeviceInsight: String? = nil
    var isLoadingInsight: Bool = false

    // AI summary state — persisted in UserDefaults so it survives navigation
    var healthSummary: String? {
        didSet { saveSummaryToDefaults() }
    }
    var summaryGeneratedDate: Date? {
        didSet { saveSummaryToDefaults() }
    }
    var isGeneratingSummary = false
    var summaryError: String?

    // MARK: - Private

    private var cachedEntries: [JournalEntry] = []
    private var cachedMedicines: [Medicine] = []
    private var cachedChecklistItems: [ChecklistItem] = []
    private let checklistService = ChecklistGenerationService(apiKey: AIConfig.llmAPIKey)

    private static let summaryTextKey = "insights.healthSummary"
    private static let summaryDateKey = "insights.healthSummaryDate"

    init() {
        // Restore persisted summary from a previous session
        healthSummary = UserDefaults.standard.string(forKey: Self.summaryTextKey)
        summaryGeneratedDate = UserDefaults.standard.object(forKey: Self.summaryDateKey) as? Date
    }

    private func saveSummaryToDefaults() {
        if let summary = healthSummary {
            UserDefaults.standard.set(summary, forKey: Self.summaryTextKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.summaryTextKey)
        }
        if let date = summaryGeneratedDate {
            UserDefaults.standard.set(date, forKey: Self.summaryDateKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.summaryDateKey)
        }
    }

    // MARK: - Load

    /// Primary entry point — call from the view whenever data changes.
    func loadData(
        from entries: [JournalEntry],
        checklistItems: [ChecklistItem] = [],
        medicines: [Medicine] = []
    ) {
        cachedEntries       = entries
        cachedMedicines     = medicines
        cachedChecklistItems = checklistItems

        loadMoodTrend(from: entries)
        reloadPeriodData()
        journalStreak         = computeStreak(from: entries)
        checklistCompletionRate = computeCompletionRate()
        loadMedicationCorrelations()
        anomalies = VitalsAnomalyDetector.detect(from: Array(entries.prefix(100)))
    }

    /// Reloads everything that depends on `selectedPeriod`.
    private func reloadPeriodData() {
        loadTagFrequency(from: cachedEntries)
        loadVitalsData(from: cachedEntries)
        triggerOnDeviceInsight()
    }

    // MARK: - Mood Trend (last 30 days, fixed)

    private func loadMoodTrend(from entries: [JournalEntry]) {
        let journalEntries = entries.filter { $0.entryType == .journal }
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()

        moodPoints = journalEntries
            .filter { $0.createdAt >= cutoff }
            .compactMap { entry in
                let mood = JournalMood.allCases.first { $0.rawValue == entry.title }
                    ?? JournalMood.allCases.first { entry.title.contains($0.rawValue) }
                guard let mood else { return nil }
                return MoodPoint(date: entry.createdAt, score: Double(mood.score), label: mood.rawValue)
            }
            .sorted { $0.date < $1.date }
    }

    // MARK: - Tag Frequency (period-filtered)

    private func loadTagFrequency(from entries: [JournalEntry]) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -selectedPeriod.rawValue, to: Date()) ?? Date()
        var freq: [String: Int] = [:]
        for entry in entries where entry.createdAt >= cutoff {
            for tag in entry.aiTags {
                let normalized = tag.trimmingCharacters(in: .whitespaces)
                guard !normalized.isEmpty else { continue }
                freq[normalized, default: 0] += 1
            }
        }
        tagCounts = freq
            .sorted { $0.value > $1.value }
            .prefix(10)
            .map { TagCount(tag: $0.key, count: $0.value) }
    }

    // MARK: - Vitals Trend Chart (period-filtered)

    private func loadVitalsData(from entries: [JournalEntry]) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -selectedPeriod.rawValue, to: Date()) ?? Date()
        let relevant = entries
            .filter { $0.entryType == .journal && $0.createdAt >= cutoff }
            .sorted { $0.createdAt < $1.createdAt }

        var data: [VitalDisplayType: [VitalDataPoint]] = [:]

        let systolicPoints = relevant.compactMap { e -> VitalDataPoint? in
            guard let bp = e.bloodPressure, let sys = parseSystolic(from: bp) else { return nil }
            return VitalDataPoint(date: e.createdAt, value: sys)
        }
        if !systolicPoints.isEmpty { data[.systolicBP] = systolicPoints }

        let hrPoints = relevant.compactMap { e -> VitalDataPoint? in
            guard let hr = e.heartRate else { return nil }
            return VitalDataPoint(date: e.createdAt, value: Double(hr))
        }
        if !hrPoints.isEmpty { data[.heartRate] = hrPoints }

        let tempPoints = relevant.compactMap { e -> VitalDataPoint? in
            guard let t = e.temperature else { return nil }
            return VitalDataPoint(date: e.createdAt, value: t)
        }
        if !tempPoints.isEmpty { data[.temperature] = tempPoints }

        let weightPoints = relevant.compactMap { e -> VitalDataPoint? in
            guard let w = e.weight else { return nil }
            return VitalDataPoint(date: e.createdAt, value: w)
        }
        if !weightPoints.isEmpty { data[.weight] = weightPoints }

        vitalsData = data
        // Auto-select the first vital type that actually has data
        if data[selectedVitalType] == nil,
           let first = VitalDisplayType.allCases.first(where: { data[$0] != nil }) {
            selectedVitalType = first
        }
    }

    // MARK: - Journal Streak

    private func computeStreak(from entries: [JournalEntry]) -> Int {
        let calendar = Calendar.current
        let journalDays = Set(
            entries
                .filter { $0.entryType == .journal }
                .map    { calendar.startOfDay(for: $0.createdAt) }
        )
        guard !journalDays.isEmpty else { return 0 }

        var streak   = 0
        var checkDay = calendar.startOfDay(for: Date())

        // Allow the streak to start from today or yesterday
        if !journalDays.contains(checkDay),
           let yesterday = calendar.date(byAdding: .day, value: -1, to: checkDay) {
            checkDay = yesterday
        }

        while journalDays.contains(checkDay) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDay) else { break }
            checkDay = prev
        }
        return streak
    }

    // MARK: - Checklist Completion Rate

    private func computeCompletionRate() -> Double? {
        let historical = ChecklistHistoryStore.shared.averageRate(forPastDays: selectedPeriod.rawValue)

        let todayTotal     = cachedChecklistItems.count
        let todayCompleted = cachedChecklistItems.filter(\.isChecked).count

        guard todayTotal > 0 else { return historical }
        let todayRate = Double(todayCompleted) / Double(todayTotal)

        // Blend today's live state with historical average
        if let hist = historical { return (hist + todayRate) / 2.0 }
        return todayRate
    }

    // MARK: - Medication Correlation

    private func loadMedicationCorrelations() {
        let lookback = 30
        var correlations: [MedicationCorrelation] = []

        for medicine in cachedMedicines {
            guard
                let beforeStart = Calendar.current.date(byAdding: .day, value: -lookback, to: medicine.startDate),
                let afterEnd    = Calendar.current.date(byAdding: .day, value:  lookback, to: medicine.startDate)
            else { continue }

            let before = cachedEntries.filter { $0.createdAt >= beforeStart && $0.createdAt < medicine.startDate }
            let after  = cachedEntries.filter { $0.createdAt >= medicine.startDate && $0.createdAt <= min(afterEnd, Date()) }

            guard before.count >= 3 else { continue }    // not enough data before

            correlations.append(MedicationCorrelation(
                medicationName: medicine.name,
                startDate: medicine.startDate,
                tagCountBefore: before.reduce(0) { $0 + $1.aiTags.count },
                tagCountAfter:  after.reduce(0)  { $0 + $1.aiTags.count }
            ))
        }
        medicationCorrelations = correlations
    }

    // MARK: - On-Device Insight (Foundation Models)

    private func triggerOnDeviceInsight() {
        guard !isLoadingInsight, !tagCounts.isEmpty else { return }
        isLoadingInsight = true
        let tagDict = Dictionary(uniqueKeysWithValues: tagCounts.map { ($0.tag, $0.count) })
        let periodLabel = self.selectedPeriod.label
        Task { @MainActor in
            var insight: String? = nil

            // 1. Try on-device Foundation Models first
            if FoundationModelsService.shared.isAvailable {
                insight = await FoundationModelsService.shared.phraseTagInsight(
                    tagCounts: tagDict,
                    periodLabel: periodLabel
                )
            }

            // 2. Gemini fallback if Foundation Models unavailable or returned nil
            if insight == nil {
                print("🤖 [InsightsViewModel] Foundation Models unavailable — falling back to Gemini for tag insight")
                insight = try? await self.checklistService.phraseTagInsight(
                    tagCounts: tagDict,
                    periodLabel: periodLabel
                )
            }

            self.onDeviceInsight = insight
            self.isLoadingInsight = false
        }
    }

    // MARK: - Deep AI Summary (Curated MD Knowledge Base)

    /// Generates a deep health-trend summary from the curated `health_summary.md`
    /// knowledge base — NOT from freshly-recomputed local stats and NOT from raw
    /// journal entries. `HealthSummaryManager` has been progressively building that
    /// file from every journal save and checkup upload (see `JournalEntryViewModel`
    /// / `CheckupViewModel`); this is the one place that curated knowledge gets
    /// turned into a narrative. Keeps the same ~90%-fewer-tokens guarantee the old
    /// compact-stats approach had, with the bonus that the cloud sees real history
    /// (lab trends, flagged abnormals, doctor notes) instead of just numbers.
    func generateDeepSummary() {
        guard !isGeneratingSummary else { return }
        isGeneratingSummary = true
        summaryError = nil
        // Keep old summary visible while refreshing (don't clear until new one arrives)

        let timeRange = selectedPeriod.insightTimeRange

        Task {
            do {
                let curatedSummary = await HealthSummaryManager.shared.getCurrentSummary()
                let insights = try await LLMAnalysisService.shared.generateHealthInsights(
                    summary: curatedSummary, timeRange: timeRange
                )
                await MainActor.run {
                    withAnimation(.spring) {
                        self.healthSummary         = Self.renderMarkdown(from: insights)
                        self.summaryGeneratedDate  = insights.generatedAt
                        self.isGeneratingSummary   = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.summaryError       = "Failed to generate summary. Please try again."
                    self.isGeneratingSummary = false
                }
            }
        }
    }

    /// Renders a `HealthInsights` result as the lightweight Markdown that
    /// `MarkdownAnalysisView` already knows how to display (`### heading` + `• bullet`).
    private static func renderMarkdown(from insights: HealthInsights) -> String {
        var parts: [String] = []

        parts.append("### Trend Summary — Past \(insights.timeRange.label)")
        parts.append(insights.trendSummary)

        if !insights.alerts.isEmpty {
            parts.append("")
            parts.append("### Signals Worth Noticing")
            for alert in insights.alerts {
                let badge: String
                switch alert.severity {
                case .info:     badge = "ℹ️"
                case .warning:  badge = "⚠️"
                case .critical: badge = "🔴"
                }
                parts.append("• \(badge) \(alert.message)")
            }
        }

        if insights.suggestDoctorVisit {
            parts.append("")
            parts.append("### A Gentle Reminder")
            parts.append("• A few signals lined up together this period — it could be worth bringing these patterns up at your next doctor's visit.")
        }

        return parts.joined(separator: "\n")
    }

    // MARK: - Private Helpers

    private func parseSystolic(from raw: String) -> Double? {
        let parts = raw.split(separator: "/")
        guard parts.count == 2, let sys = Int(parts[0].trimmingCharacters(in: .whitespaces)) else { return nil }
        return Double(sys)
    }
}
