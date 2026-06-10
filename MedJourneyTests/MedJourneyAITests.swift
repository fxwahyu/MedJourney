//
//  MedJourneyAITests.swift
//  MedJourneyTests
//
//  Unit + integration tests for the full AI call chain.
//
//  Unit tests (fast, no network):
//    - Key resolution guard: empty/placeholder key → missingAPIKey thrown
//    - LLMAnalysisService dryRun: all three call types return mock data
//    - Medication entries produce zero tags without touching the network
//
//  Integration tests (real network, ~5–30 s each):
//    - testKeyAvailability         → verifies Config.plist can be read from the app bundle
//    - testGeminiJournalTagging    → LLMTagService, journal entry → tags
//    - testGeminiCheckupAnalysis   → LLMTagService, checkup entry → tags + analysis
//    - testLLMAnalysisDailyGreeting → LLMAnalysisService, greeting endpoint
//    - testLLMAnalysisHealthInsights → LLMAnalysisService, insights endpoint
//    - testChecklistGeneration     → ChecklistGenerationService, generates ≥1 item
//
//  Run all: Product → Test (Cmd+U) — integration tests skip gracefully when the key
//  cannot be resolved (no Config.plist, no env var set).
//

import Testing
import Foundation
@testable import MedJourney

// MARK: - Bundle token (lets us locate the app bundle relative to this test bundle)

private final class AITestBundleToken: NSObject {}

// MARK: - Key resolution helper

/// Loads GEMINI_API_KEY in order:
///   1. App bundle Config.plist (the .app sits next to .xctest in DerivedData)
///   2. GEMINI_API_KEY Xcode scheme environment variable
private func resolveGeminiKey() -> String {
    let testBundle = Bundle(for: AITestBundleToken.self)
    let appBundleURL = testBundle.bundleURL
        .deletingLastPathComponent()
        .appendingPathComponent("MedJourney.app")
    if let appBundle = Bundle(url: appBundleURL),
       let configURL = appBundle.url(forResource: "Config", withExtension: "plist"),
       let cfg = NSDictionary(contentsOf: configURL) as? [String: Any],
       let key = cfg["GEMINI_API_KEY"] as? String,
       !key.isEmpty, !key.hasPrefix("YOUR_") {
        return key
    }
    return ProcessInfo.processInfo.environment["GEMINI_API_KEY"] ?? ""
}

// MARK: - Test Suite

@Suite("AI Services — Unit & Integration Tests")
struct MedJourneyAITests {

    // ─────────────────────────────────────────────────
    // MARK: Key Resolution
    // ─────────────────────────────────────────────────

    /// Confirms the test can read GEMINI_API_KEY from the app bundle's Config.plist.
    /// If this fails: Config.plist is absent from the app bundle OR the key is a placeholder.
    @Test("Key resolution: GEMINI_API_KEY loads from app bundle Config.plist")
    func testKeyAvailability() {
        let key = resolveGeminiKey()
        print("🔑 Resolved key length: \(key.count) chars, prefix: \(key.prefix(6))…")
        #expect(!key.isEmpty,
            "GEMINI_API_KEY could not be resolved. Check: (1) Config.plist is in the MedJourney target, (2) key is not YOUR_GEMINI_API_KEY_HERE")
        #expect(!key.hasPrefix("YOUR_"),
            "GEMINI_API_KEY is still the placeholder value in Config.plist")
    }

    // ─────────────────────────────────────────────────
    // MARK: Key Guards
    // ─────────────────────────────────────────────────
    //
    // Per-service "empty key throws missingAPIKey" tests were removed: API-key
    // resolution is now centralized in `LLMGateway` (Groq → Gemini), not injected
    // per service. The services (`LLMTagService`, `ChecklistGenerationService`,
    // `LLMAnalysisService`) no longer hold a key. Missing-key behavior is the
    // gateway's responsibility; it skips a provider with no key and falls through.

    // ─────────────────────────────────────────────────
    // MARK: Medication Entry Fast-Path (unit, no network)
    // ─────────────────────────────────────────────────

    /// Medication entries have no prompt — the service returns empty tags
    /// without making any network call.
    @Test("LLMTagService: medication entry returns empty tags (no network call)")
    func testMedicationEntryReturnsEmpty() async throws {
        let service = LLMTagService()
        let entry = JournalEntry(title: "Metformin 500mg", content: "Twice daily with meals", entryType: .medication)
        let result = try await service.generateTags(for: entry)
        #expect(result.tags.isEmpty, "Medication entries must return empty tags")
        #expect(result.analysis == nil, "Medication entries must return nil analysis")
    }

    // ─────────────────────────────────────────────────
    // MARK: LLMAnalysisService — dryRun (unit, no network)
    // ─────────────────────────────────────────────────

    @Test("LLMAnalysisService dryRun: analyzeCheckup returns mock summary")
    func testDryRunCheckupAnalysis() async throws {
        let service = LLMAnalysisService(dryRun: true)
        let result = try await service.analyzeCheckup(extractedText: "Hemoglobin 11.2 g/dL (low)")
        #expect(!result.summary.isEmpty, "dryRun checkup summary must not be empty")
        #expect(!result.flaggedMarkers.isEmpty, "dryRun must include at least one flagged marker")
    }

    @Test("LLMAnalysisService dryRun: generateHealthInsights returns mock trend")
    func testDryRunHealthInsights() async throws {
        let service = LLMAnalysisService(dryRun: true)
        let result = try await service.generateHealthInsights(
            summary: "BP elevated several days this week.",
            timeRange: .sevenDays
        )
        #expect(!result.trendSummary.isEmpty, "dryRun trendSummary must not be empty")
    }

    @Test("LLMAnalysisService dryRun: generateDailyGreeting returns mock message")
    func testDryRunDailyGreeting() async throws {
        let service = LLMAnalysisService(dryRun: true)
        let result = try await service.generateDailyGreeting(summaryContext: "BP stable, good sleep.")
        #expect(!result.message.isEmpty, "dryRun greeting message must not be empty")
    }

    @Test("LLMAnalysisService dryRun: generateDailyTags returns mock tags")
    func testDryRunDailyTags() async throws {
        let service = LLMAnalysisService(dryRun: true)
        let result = try await service.generateDailyTags(journalText: "Tired and headache after lunch")
        #expect(!result.isEmpty, "dryRun daily tags must return at least one tag")
    }

    // ─────────────────────────────────────────────────
    // MARK: Integration tests — real Gemini API calls
    // ─────────────────────────────────────────────────
    //
    // Each test checks key availability and prints a clear message if it skips.
    // Run with Cmd+U — they will take 5–30 s per test.

    @Test("Gemini API: tag a journal entry", .timeLimit(.minutes(2)))
    func testGeminiJournalTagging() async throws {
        let key = resolveGeminiKey()
        guard !key.isEmpty else {
            print("⚠️  [testGeminiJournalTagging] SKIPPED — no GEMINI_API_KEY resolved")
            return
        }

        let service = LLMTagService()
        let entry = JournalEntry(
            title: "Tired",
            content: "Exhausted after lunch, mild headache, drinking lots of water. BP a bit high.",
            entryType: .journal,
            bloodPressure: "138/88",
            heartRate: 82,
            temperature: 36.9
        )

        let result = try await service.generateTags(for: entry)

        print("✅ [testGeminiJournalTagging] Tags (\(result.tags.count)): \(result.tags.joined(separator: ", "))")
        #expect(!result.tags.isEmpty, "Gemini should return ≥1 tag for a journal entry")
        #expect(result.analysis == nil, "Journal entries should not return analysis (only checkups do)")
    }

    @Test("Gemini API: analyze a checkup entry", .timeLimit(.minutes(2)))
    func testGeminiCheckupAnalysis() async throws {
        let key = resolveGeminiKey()
        guard !key.isEmpty else {
            print("⚠️  [testGeminiCheckupAnalysis] SKIPPED — no GEMINI_API_KEY resolved")
            return
        }

        let service = LLMTagService()
        let entry = JournalEntry(
            title: "Lab Results — Mayapada Hospital",
            content: "Emergency Department visit. CBC, COVID/Influenza rapid panel.",
            entryType: .checkup
        )
        let ocrText = """
        Hemoglobin 16.4 g/dL (normal), RBC 5.6 (H, slightly elevated),
        Monocytes 15.4% (H), Lymphocytes 21.5% (L),
        COVID-19 Negative, Influenza A Negative, Influenza B Negative,
        Dengue NS1 Ag Negative.
        """

        let result = try await service.generateTags(for: entry, ocrText: ocrText)

        print("✅ [testGeminiCheckupAnalysis] Tags (\(result.tags.count)): \(result.tags.joined(separator: ", "))")
        if let analysis = result.analysis {
            print("📝 Analysis (first 300 chars): \(analysis.prefix(300))…")
        }
        #expect(!result.tags.isEmpty, "Gemini should return tags for a checkup entry")
        #expect(result.analysis != nil, "Gemini should return structured analysis for a checkup")
    }

    @Test("Gemini API: LLMAnalysisService — daily greeting", .timeLimit(.minutes(2)))
    func testLLMAnalysisDailyGreeting() async throws {
        let key = resolveGeminiKey()
        guard !key.isEmpty else {
            print("⚠️  [testLLMAnalysisDailyGreeting] SKIPPED — no GEMINI_API_KEY resolved")
            return
        }

        let service = LLMAnalysisService(dryRun: false)
        let greeting = try await service.generateDailyGreeting(
            summaryContext: "BP was 132/85 yesterday. Patient is on Metformin and Amlodipine. Energy improving."
        )

        print("✅ [testLLMAnalysisDailyGreeting] Message: \(greeting.message)")
        print("   Tone: \(greeting.tone.rawValue)")
        #expect(!greeting.message.isEmpty, "LLMAnalysisService should return a non-empty greeting")
    }

    @Test("Gemini API: LLMAnalysisService — health insights", .timeLimit(.minutes(2)))
    func testLLMAnalysisHealthInsights() async throws {
        let key = resolveGeminiKey()
        guard !key.isEmpty else {
            print("⚠️  [testLLMAnalysisHealthInsights] SKIPPED — no GEMINI_API_KEY resolved")
            return
        }

        let service = LLMAnalysisService(dryRun: false)
        let insights = try await service.generateHealthInsights(
            summary: """
            Patient: Type 2 diabetes. Medications: Metformin 500mg, Glipizide 5mg, Amlodipine 5mg.
            Recent tags: fatigue, elevated BP, dizziness, headache.
            BP readings past 7 days: 132/85, 134/86, 128/84, 130/83, 138/88.
            """,
            timeRange: .sevenDays
        )

        print("✅ [testLLMAnalysisHealthInsights] Trend: \(insights.trendSummary.prefix(200))")
        print("   Alerts: \(insights.alerts.map { "\($0.severity.rawValue): \($0.message)" }.joined(separator: "; "))")
        #expect(!insights.trendSummary.isEmpty, "Health insights should contain a trend summary")
    }

    @Test("Gemini API: ChecklistGenerationService — generate daily habits", .timeLimit(.minutes(2)))
    func testChecklistGeneration() async throws {
        let key = resolveGeminiKey()
        guard !key.isEmpty else {
            print("⚠️  [testChecklistGeneration] SKIPPED — no GEMINI_API_KEY resolved")
            return
        }

        let service = ChecklistGenerationService()
        let items = try await service.generateChecklist(
            ocrText: "Hemoglobin 16.4 g/dL. RBC 5.6 (slightly elevated). Monocytes 15.4% (elevated). All infection panels negative.",
            notes: "Type 2 diabetes patient. On Metformin 500mg twice daily and Amlodipine 5mg at night."
        )

        print("✅ [testChecklistGeneration] Items (\(items.count)):")
        items.forEach { print("   \($0.emoji) \($0.text)") }
        #expect(!items.isEmpty, "ChecklistGenerationService should return at least one checklist item")
        #expect(items.count <= 5, "ChecklistGenerationService must return at most 5 items")
    }

    /// Exercises the exact code path that InsightsViewModel.generateDeepSummary() uses.
    /// If this passes but the in-app button fails, the issue is in key resolution (Config.plist
    /// not in app bundle) rather than in the network stack.
    @Test("Gemini API: full deep-insight path (mirrors InsightsViewModel.generateDeepSummary)", .timeLimit(.minutes(2)))
    func testDeepInsightFullPath() async throws {
        let key = resolveGeminiKey()
        guard !key.isEmpty else {
            print("⚠️  [testDeepInsightFullPath] SKIPPED — no GEMINI_API_KEY resolved")
            return
        }

        // Simulate what HealthSummaryManager.getCurrentSummary() returns after seed data
        let fakeSummary = """
        # Health Summary
        ## Active Conditions
        - Type 2 Diabetes (on Metformin, Glipizide)
        - Stage 1 Hypertension (on Amlodipine)
        ## Recent Journal Tags
        - fatigue, elevated-BP, dizziness, headache, nausea
        ## Flagged Abnormals
        - HbA1c 8.2% (normal: <5.7%) — from checkup
        - Monocytes 15.4% (normal: 4-10%) — elevated
        ## Daily Summary Context
        Two consecutive days of dizziness and elevated heart rate (HR 86-88).
        """

        let service = LLMAnalysisService(dryRun: false)
        let insights = try await service.generateHealthInsights(
            summary: fakeSummary,
            timeRange: .thirtyDays
        )

        print("✅ [testDeepInsightFullPath] trendSummary: \(insights.trendSummary.prefix(200))")
        print("   alerts: \(insights.alerts.count), suggestVisit: \(insights.suggestDoctorVisit)")
        #expect(!insights.trendSummary.isEmpty, "Deep insight trend summary should not be empty")
    }

    @Test("Gemini API: phraseTagInsight from ChecklistGenerationService", .timeLimit(.minutes(2)))
    func testPhraseTagInsight() async throws {
        let key = resolveGeminiKey()
        guard !key.isEmpty else {
            print("⚠️  [testPhraseTagInsight] SKIPPED — no GEMINI_API_KEY resolved")
            return
        }

        let service = ChecklistGenerationService()
        let tagCounts: [String: Int] = [
            "fatigue": 8,
            "headache": 5,
            "elevated BP": 4,
            "dizziness": 3,
            "nausea": 2
        ]

        let insight = try await service.phraseTagInsight(tagCounts: tagCounts, periodLabel: "30 days")

        print("✅ [testPhraseTagInsight] Insight: \(insight)")
        #expect(!insight.isEmpty, "phraseTagInsight should return a non-empty narrative sentence")
    }
}
