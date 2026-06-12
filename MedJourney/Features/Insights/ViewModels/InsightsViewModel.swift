//
//  InsightsViewModel.swift
//  MedJourney
//

import SwiftUI
import SwiftData

/// Stats and AI insights for the Insights tab. All chart statistics are computed
/// locally in Swift; the AI layer only ever phrases pre-computed stats (on-device)
/// or summarises the curated health summary (cloud).
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

        var insightTimeRange: InsightTimeRange {
            switch self {
            case .week:    return .sevenDays
            case .month:   return .thirtyDays
            case .quarter: return .custom(DateInterval(start: Date().addingTimeInterval(-90 * 86_400), end: Date()))
            }
        }
    }

    /// Which vital is displayed on the vitals trend chart.
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

    // MARK: - Observable State

    var moodPoints: [MoodPoint] = []
    var tagCounts: [TagCount] = []

    var selectedPeriod: InsightPeriod = .month {
        didSet {
            onDeviceInsight = nil
            reloadPeriodData()
        }
    }

    var vitalsData: [VitalDisplayType: [VitalDataPoint]] = [:]
    var selectedVitalType: VitalDisplayType = .systolicBP

    var journalStreak = 0
    var checklistCompletionRate: Double?

    var anomalies: [VitalsAnomaly] = []

    var onDeviceInsight: String?
    var isLoadingInsight = false

    // Deep AI summary — persisted in UserDefaults so it survives navigation.
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
    private var cachedChecklistItems: [ChecklistItem] = []

    private static let summaryTextKey = "insights.healthSummary"
    private static let summaryDateKey = "insights.healthSummaryDate"

    init() {
        healthSummary = UserDefaults.standard.string(forKey: Self.summaryTextKey)
        summaryGeneratedDate = UserDefaults.standard.object(forKey: Self.summaryDateKey) as? Date
    }

    // MARK: - Load

    /// Full load on first appear — includes requesting the on-device AI insight.
    func loadData(from entries: [JournalEntry], checklistItems: [ChecklistItem] = []) {
        cachedEntries = entries
        cachedChecklistItems = checklistItems

        loadMoodTrend(from: entries)
        reloadPeriodData()
        journalStreak = computeStreak(from: entries)
        checklistCompletionRate = computeCompletionRate()
        anomalies = VitalsAnomalyDetector.detect(from: Array(entries.prefix(100)))
    }

    /// Lightweight refresh when data changes mid-session — charts and stats only,
    /// no new AI call (the existing insight stays valid for the period).
    func refreshData(from entries: [JournalEntry], checklistItems: [ChecklistItem] = []) {
        cachedEntries = entries
        cachedChecklistItems = checklistItems

        loadMoodTrend(from: entries)
        loadTagFrequency(from: entries)
        loadVitalsData(from: entries)
        journalStreak = computeStreak(from: entries)
        checklistCompletionRate = computeCompletionRate()
        anomalies = VitalsAnomalyDetector.detect(from: Array(entries.prefix(100)))
    }

    private func reloadPeriodData() {
        loadTagFrequency(from: cachedEntries)
        loadVitalsData(from: cachedEntries)
        triggerOnDeviceInsight()
    }

    // MARK: - Mood Trend (last 30 days)

    private func loadMoodTrend(from entries: [JournalEntry]) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()

        moodPoints = entries
            .filter { $0.entryType == .journal && $0.createdAt >= cutoff }
            .compactMap { entry in
                let mood = JournalMood.allCases.first { $0.rawValue == entry.title }
                    ?? JournalMood.allCases.first { entry.title.contains($0.rawValue) }
                guard let mood else { return nil }
                return MoodPoint(date: entry.createdAt, score: Double(mood.score), label: mood.rawValue)
            }
            .sorted { $0.date < $1.date }
    }

    // MARK: - Tag Frequency (period-filtered)

    /// Meta/status words excluded from the Symptom Frequency chart so only real,
    /// patient-facing symptoms are shown.
    private static let nonSymptomTags: Set<String> = [
        "monitoring", "routine monitoring", "routine", "concern", "exercise",
        "improving", "improved mood", "improved energy", "positive", "positive outlook",
        "diabetes management", "diabetes monitoring", "weight management", "weight tracking",
        "weight stable", "weight loss", "hydration", "diet success", "dietary adherence",
        "dietary awareness", "diet adjustment", "good sleep", "lifestyle change",
        "medication initiation", "medication tolerating", "medication adherence",
        "treatment responding", "progress", "hopeful", "adaptation", "lesson learned",
        "doctor appointment", "health concern", "reminder needed", "combination therapy",
        "non diabetes related", "blood pressure normal", "blood pressure stable",
        "infection ruled out", "dizziness workup", "immune response", "metformin adjustment",
        "medication side effect", "medication effect", "medication complexity",
        "adherence reminder", "diabetes symptom", "glucose fluctuation", "eye concern",
        "glucose risk", "infection monitoring", "cold recovering", "metformin started",
        "amlodipine started", "glipizide started", "metformin reaction", "glipizide side effect",
        "glipizide risk", "possible hypoglycemia", "hypoglycemia risk", "medication adjustment",
        "diabetes type2 diagnosed", "hypertension stage1", "busy schedule",
        "diet disruption", "afternoon crash", "sedentary behavior", "mental health"
    ]

    /// "work-stress" → "work stress": hyphens/underscores to spaces, trimmed, lowercased.
    private static func humanize(_ tag: String) -> String {
        tag.replacingOccurrences(of: "-", with: " ")
           .replacingOccurrences(of: "_", with: " ")
           .trimmingCharacters(in: .whitespaces)
           .lowercased()
    }

    private func loadTagFrequency(from entries: [JournalEntry]) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -selectedPeriod.rawValue, to: Date()) ?? Date()
        var frequency: [String: Int] = [:]

        // Only journal entries carry day-to-day symptoms; checkup/medication entries
        // hold lab findings and admin tags.
        for entry in entries where entry.entryType == .journal && entry.createdAt >= cutoff {
            for tag in entry.aiTags {
                let label = Self.humanize(tag)
                guard !label.isEmpty, !Self.nonSymptomTags.contains(label) else { continue }
                frequency[label, default: 0] += 1
            }
        }
        tagCounts = frequency
            .sorted { $0.value > $1.value }
            .prefix(10)
            .map { TagCount(tag: $0.key, count: $0.value) }
    }

    // MARK: - Vitals Trend (period-filtered)

    private func loadVitalsData(from entries: [JournalEntry]) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -selectedPeriod.rawValue, to: Date()) ?? Date()
        let relevant = entries
            .filter { $0.entryType == .journal && $0.createdAt >= cutoff }
            .sorted { $0.createdAt < $1.createdAt }

        var data: [VitalDisplayType: [VitalDataPoint]] = [:]

        let series: [(VitalDisplayType, (JournalEntry) -> Double?)] = [
            (.systolicBP,  { $0.bloodPressure.flatMap(Self.parseSystolic) }),
            (.heartRate,   { $0.heartRate.map(Double.init) }),
            (.temperature, { $0.temperature }),
            (.weight,      { $0.weight }),
        ]
        for (type, value) in series {
            let points = relevant.compactMap { entry in
                value(entry).map { VitalDataPoint(date: entry.createdAt, value: $0) }
            }
            if !points.isEmpty { data[type] = points }
        }

        vitalsData = data
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
                .map { calendar.startOfDay(for: $0.createdAt) }
        )
        guard !journalDays.isEmpty else { return 0 }

        var streak = 0
        var checkDay = calendar.startOfDay(for: Date())

        // The streak may start from today or yesterday.
        if !journalDays.contains(checkDay),
           let yesterday = calendar.date(byAdding: .day, value: -1, to: checkDay) {
            checkDay = yesterday
        }
        while journalDays.contains(checkDay) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: checkDay) else { break }
            checkDay = previous
        }
        return streak
    }

    // MARK: - Checklist Completion Rate

    /// Blends today's live completion with the historical average for the period.
    private func computeCompletionRate() -> Double? {
        let historical = ChecklistHistoryStore.shared.averageRate(forPastDays: selectedPeriod.rawValue)

        let todayTotal = cachedChecklistItems.count
        guard todayTotal > 0 else { return historical }
        let todayRate = Double(cachedChecklistItems.filter(\.isChecked).count) / Double(todayTotal)

        if let historical { return (historical + todayRate) / 2.0 }
        return todayRate
    }

    // MARK: - On-Device Insight

    private func triggerOnDeviceInsight() {
        // `onDeviceInsight` is cleared in `selectedPeriod.didSet`, so a period change
        // always requests a fresh insight while re-entering the tab does not.
        guard !isLoadingInsight, !tagCounts.isEmpty, onDeviceInsight == nil else { return }

        // Set synchronously before the Task so concurrent onChange callbacks on the
        // same run loop tick can't all pass the guard.
        isLoadingInsight = true
        let tagDict = Dictionary(uniqueKeysWithValues: tagCounts.map { ($0.tag, $0.count) })
        let periodLabel = selectedPeriod.label

        Task { @MainActor in
            // On-device only — without Apple Intelligence the insight sentence
            // simply isn't shown (saves an API call).
            let insight: String? = FoundationModelsService.shared.isAvailable
                ? await FoundationModelsService.shared.phraseTagInsight(
                    tagCounts: tagDict,
                    periodLabel: periodLabel
                  )
                : nil
            self.onDeviceInsight = insight
            self.isLoadingInsight = false
        }
    }

    // MARK: - Deep AI Summary

    /// Generates the deep health-trend narrative from the curated `health_summary.md`
    /// knowledge base — never from raw journal entries.
    func generateDeepSummary() {
        guard !isGeneratingSummary else { return }
        isGeneratingSummary = true
        summaryError = nil

        let timeRange = selectedPeriod.insightTimeRange

        Task {
            do {
                let curatedSummary = await HealthSummaryManager.shared.getCurrentSummary()
                let insights = try await LLMAnalysisService.shared.generateHealthInsights(
                    summary: curatedSummary, timeRange: timeRange
                )
                await MainActor.run {
                    withAnimation(.spring) {
                        self.healthSummary = Self.renderMarkdown(from: insights)
                        self.summaryGeneratedDate = insights.generatedAt
                        self.isGeneratingSummary = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.summaryError = Self.errorMessage(for: error)
                    self.isGeneratingSummary = false
                }
            }
        }
    }

    private static func errorMessage(for error: Error) -> String {
        switch error {
        case LLMError.missingAPIKey:
            return "API key not configured. Add GEMINI_API_KEY to Config.plist."
        case LLMError.apiError(429):
            return "Rate limit reached — too many requests in a short window. Wait a minute and try again."
        case LLMError.apiError(let code):
            return "Network error (HTTP \(code)). Check your connection and try again."
        case LLMError.parseError:
            return "Failed to read AI response. Please try again."
        default:
            return "Failed to generate summary: \(error.localizedDescription)"
        }
    }

    /// Renders a `HealthInsights` result as the lightweight markdown
    /// `MarkdownAnalysisView` displays (`### heading` + `• bullet`).
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

    // MARK: - Helpers

    private static func parseSystolic(from raw: String) -> Double? {
        let parts = raw.split(separator: "/")
        guard parts.count == 2, let systolic = Int(parts[0].trimmingCharacters(in: .whitespaces)) else { return nil }
        return Double(systolic)
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
}
