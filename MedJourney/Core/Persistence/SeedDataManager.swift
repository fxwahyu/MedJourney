// SeedDataManager.swift
// MedJourney — Demo seed data for video showcase
//
// Seeds 15 entries of a realistic Type 2 diabetes patient journey (over ~15 days)
// into SwiftData and the health_summary.md file. Runs once per seed-version on first
// launch (gated by UserDefaults). After seeding, opens the app directly to the main
// view (bypasses onboarding).
//
// The 15 entries = 11 journal entries + 2 diabetes checkups + 1 ED-visit checkup,
// plus 3 medications. Bumping `seedKey` re-seeds on next launch and clears any
// previously-seeded entries first (see `clearExistingSeedData`) to avoid duplicates.
//
// ANOMALY TRIGGER FOR DEMO:
//   The seeded BP baseline is ~129/83 (std dev ~2.4/1.4).
//   To trigger the anomaly warning during demo, add a new journal entry with
//   Blood Pressure: 148/95 (or higher). The detector will flag it as ~8σ
//   above the personal baseline with the message:
//   "Your systolic bp has been above your personal average for 2 consecutive
//    readings. Consider mentioning this to your doctor."
//   Tip: add one entry at ~148/95 first, then add another at ~152/96 to get
//   the "consecutive readings" version of the message.

import Foundation
import SwiftData

enum SeedDataManager {

    // Bump this version to force a re-seed on next launch. Re-seeding clears any
    // previously-seeded data first, so upgrading never produces duplicates.
    private static let seedKey = "medjourney_demo_seed_v3"

    // MARK: - Entry Point

    static func seedIfNeeded(context: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: seedKey) else { return }

        // A previous seed version may have inserted entries — clear them so the new
        // seed doesn't stack on top and create duplicates.
        clearExistingSeedData(context: context)

        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        func daysAgo(_ n: Int) -> Date {
            cal.date(byAdding: .day, value: -n, to: today) ?? today
        }
        func at(_ hour: Int, _ minute: Int, on base: Date) -> Date {
            cal.date(bySettingHour: hour, minute: minute, second: 0, of: base) ?? base
        }

        let checkupID1 = UUID() // May 7 first diagnosis
        let checkupID2 = UUID() // May 20 monthly check
        let checkupID3 = UUID() // Jun 3 progress review

        seedMedicines(context: context, today: today, at: at)
        seedJournalEntries(context: context, daysAgo: daysAgo, at: at,
                           c1: checkupID1, c2: checkupID2, c3: checkupID3)
        seedChecklistItems(context: context, checkupID: checkupID1)
        seedChecklistHistory(daysAgo: daysAgo)
        seedHealthSummaryMarkdown(daysAgo: daysAgo)

        UserDefaults.standard.set(true, forKey: "hasOnboarded")
        UserDefaults.standard.set(true, forKey: seedKey)
        try? context.save()
    }

    // MARK: - Cleanup (re-seed safety)

    /// Removes any previously-seeded demo data so a re-seed (after a version bump)
    /// doesn't stack new entries on top of old ones. Also clears the in-memory
    /// HealthSummaryManager cache so the freshly-written MD file is read on next access.
    private static func clearExistingSeedData(context: ModelContext) {
        try? context.delete(model: JournalEntry.self)
        try? context.delete(model: Medicine.self)
        try? context.delete(model: ChecklistItem.self)
        try? context.save()

        // Drop the old checklist-history cache too (keyed in UserDefaults).
        UserDefaults.standard.removeObject(forKey: "medjourney_checklist_history_v1")
    }

    // MARK: - Medicines

    private static func seedMedicines(
        context: ModelContext,
        today: Date,
        at: (Int, Int, Date) -> Date
    ) {
        let cal = Calendar.current
        func daysAgo(_ n: Int) -> Date {
            cal.date(byAdding: .day, value: -n, to: today) ?? today
        }

        let medicines: [(String, String, String, Date)] = [
            (
                "Metformin 500mg",
                "Take with meal. Controls blood sugar by reducing glucose production in the liver. May cause mild nausea initially.",
                "07:00,19:00",
                daysAgo(12)   // started with diagnosis
            ),
            (
                "Glipizide 5mg",
                "Take 30 minutes before first meal. Stimulates pancreas to release insulin. Do not skip meals after taking.",
                "07:00",
                daysAgo(8)    // added at follow-up
            ),
            (
                "Amlodipine 5mg",
                "Take before bed. Controls blood pressure. Do not take with grapefruit juice.",
                "21:00",
                daysAgo(12)   // started with diagnosis
            ),
        ]

        for (name, notes, times, start) in medicines {
            context.insert(Medicine(
                name: name,
                notes: notes,
                notificationTimesRaw: times,
                isActive: true,
                startDate: start,
                createdAt: start
            ))
        }
    }

    // MARK: - Journal Entries

    private static func seedJournalEntries(
        context: ModelContext,
        daysAgo: (Int) -> Date,
        at: (Int, Int, Date) -> Date,
        c1: UUID, c2: UUID, c3: UUID
    ) {
        let entries = buildEntries(daysAgo: daysAgo, at: at, c1: c1, c2: c2, c3: c3)
        for e in entries { context.insert(e) }
    }

    // swiftlint:disable function_body_length
    private static func buildEntries(
        daysAgo: (Int) -> Date,
        at: (Int, Int, Date) -> Date,
        c1: UUID, c2: UUID, c3: UUID
    ) -> [JournalEntry] {

        func j(
            daysBack: Int, hour: Int = 21, min: Int = 0,
            title: String, content: String,
            discomfort: Int? = nil,
            bp: String? = nil, hr: Int? = nil, temp: Double? = nil, weight: Double? = nil,
            tags: String,
            type: JournalEntry.EntryType = .journal,
            analysis: String? = nil,
            images: [Data]? = nil,
            id: UUID? = nil
        ) -> JournalEntry {
            let date = at(hour, min, daysAgo(daysBack))
            return JournalEntry(
                id: id ?? UUID(),
                title: title,
                content: content,
                entryType: type,
                discomfortLevel: discomfort,
                bloodPressure: bp,
                heartRate: hr,
                temperature: temp,
                weight: weight,
                aiTagsRaw: tags,
                aiAnalysis: analysis,
                attachedImagesData: images,
                createdAt: date,
                updatedAt: date
            )
        }

        return [
            // Day 1 — 15 days ago — initial symptoms
            j(daysBack: 15, hour: 22, min: 10,
              title: "Tired",
              content: "I've been drinking water non-stop today but still feel parched. Had to use the bathroom maybe 7 or 8 times. Also felt unusually tired after lunch even though I didn't do anything strenuous. Google says excessive thirst can be a diabetes symptom — going to book a doctor appointment tomorrow.",
              discomfort: 3,
              tags: "excessive thirst, frequent urination, fatigue"),

            // Day 2 — 14 days ago — appointment booked
            j(daysBack: 14, hour: 21, min: 30,
              title: "Anxious",
              content: "Managed to get an appointment for tomorrow morning. Still very thirsty and tired. Also noticed my vision was a bit blurry after dinner, which is unusual for me. Going to mention all of this to the doctor. Trying not to overthink it but I'm a bit worried.",
              discomfort: 3,
              tags: "blurry vision, fatigue, anxiety"),

            // Day 3 — 13 days ago — CHECKUP 1 (diagnosis)
            j(daysBack: 13, hour: 10, min: 45,
              title: "Blood test results — diabetes confirmed",
              content: "Doctor ordered a fasting blood glucose and HbA1c. Results came back in the afternoon. HbA1c is 8.2% and fasting glucose is 168 mg/dL — both significantly elevated. Doctor confirmed Type 2 Diabetes diagnosis. Also found LDL slightly high at 142. Will be prescribed medication. Feeling shocked and scared right now.",
              tags: "HbA1c-elevated,glucose-high,cholesterol-borderline,diabetes-type2-diagnosed,hypertension-stage1",
              type: .checkup,
              analysis: checkupAnalysis1,
              id: c1),

            // Day 4 — 12 days ago — medications started
            j(daysBack: 12, hour: 9, min: 15,
              title: "Started Metformin and Amlodipine",
              content: "Picked up prescriptions this morning. Starting Metformin 500mg twice a day with meals, and Amlodipine 5mg at night for blood pressure. Pharmacist explained possible nausea from Metformin in the first few weeks and told me to always take it with food. Feeling nervous about all this but trying to stay positive. Going to make dietary changes too — cutting out rice at dinner and avoiding sugary drinks.",
              tags: "metformin-started,amlodipine-started,diabetes-management,medication-initiation,lifestyle-change",
              type: .medication),

            // Day 5 — 11 days ago — nausea side effect
            j(daysBack: 11, hour: 20, min: 0,
              title: "Sick",
              content: "Woke up feeling queasy this morning. Took Metformin with breakfast like I was told but still got nauseated within an hour. Had to sit down at work. Skipped my mid-morning coffee, which helped a bit. Dinner was hard to eat. BP seems okay. Hoping this side effect passes soon as the pharmacist said it usually does within 1-2 weeks.",
              discomfort: 5,
              bp: "126/82", hr: 78,
              tags: "nausea, reduced appetite"),

            // Day 6 — 10 days ago — nausea easing, started walking
            j(daysBack: 10, hour: 20, min: 30,
              title: "Tired",
              content: "Nausea seems to be letting up a bit today. Managed a full breakfast without feeling terrible afterward. Went for a short 15-minute walk in the evening which helped my mood. Tracking calories and trying to eat more vegetables and less refined carbs. Weight at 82.5 kg today — was 83.2 a few weeks ago so small progress. Heart rate seems normal.",
              discomfort: 2,
              hr: 76, weight: 82.5,
              tags: "fatigue, low energy"),

            // Day 7 — 9 days ago — routine, improving
            j(daysBack: 9, hour: 21, min: 15,
              title: "Neutral",
              content: "No major complaints today. Took both medications on time. Still trying to drink 8 glasses of water a day — the thirst is less intense than it was last week which I take as a good sign. Blood pressure reading was normal. Meal plan is getting easier to follow. Work was busy so didn't have time to dwell on things.",
              discomfort: 2,
              bp: "128/82", hr: 76,
              tags: "mild thirst"),

            // Day 8 — 8 days ago — CHECKUP 2 (improvement, Glipizide added)
            j(daysBack: 8, hour: 11, min: 0,
              title: "Follow-up check-up — blood sugar improving",
              content: "Great news from the doctor today. HbA1c dropped from 8.2% to 7.4%, and fasting glucose is down to 132 mg/dL. Doctor says the Metformin is working and the dietary changes are helping. LDL is still borderline at 138 but trending down. Doctor wants to add Glipizide 5mg to accelerate the improvement. Overall feeling encouraged.",
              tags: "HbA1c-improving,glucose-decreasing,cholesterol-borderline,treatment-responding,progress,glipizide-started",
              type: .checkup,
              analysis: checkupAnalysis2,
              id: c2),

            // Day 9 — 7 days ago — energy better, weight down
            j(daysBack: 7, hour: 19, min: 0,
              title: "Good",
              content: "Went for a 30-minute walk with my wife this evening. Felt genuinely good afterward — both physically and mentally. Weight is 82.0 kg. Energy levels were noticeably better in the afternoon compared to last week. Managing diet is becoming a habit now. Less stressed about the diagnosis than I was at first.",
              discomfort: 1,
              hr: 77, weight: 82.0,
              tags: ""),   // good day — no symptoms to log

            // Day 10 — 6 days ago — insomnia, headache
            j(daysBack: 6, hour: 22, min: 30,
              title: "Pain",
              content: "Didn't sleep well last night — woke up around 2am and couldn't fall back asleep until 5am. Woke up with a headache that lasted most of the morning. No idea what caused the insomnia. Could be stress at work or just my body adjusting to the new Glipizide. Took it easy today. Going to try a decaf evening routine.",
              discomfort: 5,
              tags: "headache, insomnia, fatigue, stress"),

            // Day 11 — 5 days ago — slept well, weight loss
            j(daysBack: 5, hour: 19, min: 30,
              title: "Good",
              content: "Finally slept well last night. Woke up refreshed for the first time in a while. Weighed myself and I'm at 81.8 kg — that's 1.4 kg less than when I started. Going for a walk felt easier today. Diet has been consistent for two weeks now. Mood is much better when I have energy.",
              discomfort: 1,
              weight: 81.8,
              tags: ""),   // good day — no symptoms to log

            // Day 12 — 4 days ago — CHECKUP 3 (ED visit, infection ruled out)
            j(daysBack: 4, hour: 11, min: 30,
              title: "ED visit — blood panel and infection screening",
              content: "After lingering cold symptoms and some dizziness, my wife insisted I go to the emergency department. They ran a full blood count plus rapid panels for COVID-19, influenza, and dengue. Everything came back the same evening. All infection panels were negative. Blood work showed slightly elevated monocytes and mildly low lymphocytes — the doctor said this is consistent with a recent or resolving viral illness. RBC was a touch high which they attributed to possible mild dehydration. Relieved it's nothing more serious. Doctor advised to continue all diabetes medications without change and stay well hydrated.",
              tags: "ED-visit,infection-ruled-out,monocytes-elevated,lymphocytes-low,immune-response,dizziness-workup,dehydration-possible",
              type: .checkup,
              analysis: checkupAnalysis3,
              images: loadBundleImages(names: [("lab_page1", "jpg"), ("lab_page2", "jpg")]),
              id: c3),

            // Day 13 — 3 days ago — elevated BP, work stress
            j(daysBack: 3, hour: 21, min: 0,
              title: "Anxious",
              content: "Checked blood pressure this morning and it was 134/86 — the highest in a while. Heart rate was also slightly elevated at 84. End of a really intense work week with multiple deadlines and I've been eating at my desk. Took all medications correctly today. Will keep a closer eye on BP over the next few days.",
              discomfort: 3,
              bp: "134/86", hr: 84,
              tags: "high blood pressure, elevated heart rate, stress"),

            // Day 14 — 2 days ago — dizzy spell
            j(daysBack: 2, hour: 21, min: 0,
              title: "Sick",
              content: "Experienced a dizzy spell around 7pm out of nowhere. Had to hold the wall for a second. It passed quickly but left me feeling uneasy. No chest pain, no shortness of breath. Heart rate seemed a bit fast. I wonder if it's from the stress lately or skipping a proper lunch. Going to take it easy tonight and check my BP in the morning.",
              discomfort: 5,
              hr: 86,
              tags: "dizziness, lightheadedness, elevated heart rate"),

            // Day 15 — yesterday — recurring dizziness, concern
            j(daysBack: 1, hour: 20, min: 30,
              title: "Sick",
              content: "Woke up feeling okay but by the evening I had that same unsettled feeling as yesterday. Heart rate at 88 which is on the higher side for me. Weight stable at 81.3 kg. Going to measure BP tomorrow morning — after two days of dizziness I should really check it. Took all medications on time. Mentioned the dizziness to my wife and she's also concerned. Will call the clinic if it continues.",
              discomfort: 4,
              hr: 88, weight: 81.3,
              tags: "fatigue, elevated heart rate, dizziness"),
        ]
    }
    // swiftlint:enable function_body_length

    // MARK: - Bundle Image Loader

    private static func loadBundleImages(names: [(String, String)]) -> [Data]? {
        let loaded = names.compactMap { (name, ext) -> Data? in
            guard let url = Bundle.main.url(forResource: name, withExtension: ext) else { return nil }
            return try? Data(contentsOf: url)
        }
        return loaded.isEmpty ? nil : loaded
    }

    // MARK: - Checklist Items

    private static func seedChecklistItems(context: ModelContext, checkupID: UUID) {
        // Max 5 items — medicine intake excluded (handled by Medicine Schedule card)
        let items: [(String, String, Int)] = [
            ("Walk at least 20 minutes", "🚶", 0),
            ("Drink 8 glasses of water", "💧", 1),
            ("Avoid sugary drinks and snacks", "🍽️", 2),
            ("Monitor blood glucose if available", "📊", 3),
            ("Get 7–8 hours of sleep", "😴", 4),
        ]
        let today = Calendar.current.startOfDay(for: Date())
        for (text, emoji, order) in items {
            context.insert(ChecklistItem(
                text: text,
                emoji: emoji,
                isChecked: false,
                sortOrder: order,
                sourceCheckupId: checkupID,
                createdAt: today
            ))
        }
    }

    // MARK: - Checklist History (UserDefaults)

    private static func seedChecklistHistory(daysAgo: (Int) -> Date) {
        // 30 days of records — varied completion rates reflecting realistic adherence
        let rates: [(Int, Int, Int)] = [
            (30, 8, 6), (29, 8, 5), (28, 8, 7), (27, 10, 4), (26, 10, 6),
            (25, 10, 8), (24, 10, 9), (23, 10, 7), (22, 10, 8), (21, 10, 6),
            (20, 10, 9), (19, 10, 10), (18, 10, 7), (17, 10, 8), (16, 10, 9),
            (15, 10, 6), (14, 10, 10), (13, 10, 8), (12, 10, 7), (11, 10, 9),
            (10, 10, 8), (9, 10, 6), (8, 10, 9), (7, 10, 8), (6, 10, 10),
            (5, 10, 7), (4, 10, 8), (3, 10, 9), (2, 10, 6), (1, 10, 8),
        ]
        let records = rates.map {
            DailyChecklistRecord(date: daysAgo($0.0), total: $0.1, completed: $0.2)
        }
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: "medjourney_checklist_history_v1")
        }
    }

    // MARK: - health_summary.md

    private static func seedHealthSummaryMarkdown(daysAgo: (Int) -> Date) {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = docs.appendingPathComponent("health_summary.md")
        let content = buildHealthSummaryMarkdown(daysAgo: daysAgo)
        try? content.data(using: .utf8)?.write(to: fileURL, options: .atomic)
    }

    private static func buildHealthSummaryMarkdown(daysAgo: (Int) -> Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        func d(_ n: Int) -> String { df.string(from: daysAgo(n)) }

        return """
        # Health Summary
        **Last Updated:** \(ISO8601DateFormatter().string(from: daysAgo(1)))
        **User Profile:** Age: 42 | Blood Type: —

        ## Active Conditions
        - Type 2 Diabetes Mellitus (diagnosed \(d(13)))
        - Hypertension Stage 1 (monitored, on Amlodipine)

        ## Lab Trends
        | Marker | Normal Range | Status |
        |--------|--------------|--------|
        | HbA1c | <5.7% | Improving: 8.2% → 7.4% |
        | Fasting Glucose | 70–99 mg/dL | Improving: 168 → 132 mg/dL |
        | LDL Cholesterol | <100 mg/dL | Borderline improving: 142 → 138 mg/dL |
        | Triglycerides | <150 mg/dL | Borderline: 198 mg/dL (at diagnosis) |
        | Blood Pressure | <120/80 mmHg | Monitored: typically 126–134/82–86 |

        ## Recent Journal Tags (last 30 entries max)
        - \(d(15)): excessive thirst, frequent urination, fatigue
        - \(d(14)): blurry vision, fatigue, anxiety
        - \(d(11)): nausea, reduced appetite | Vitals: BP 126/82, HR 78
        - \(d(10)): fatigue, low energy | Vitals: HR 76, Weight 82.5
        - \(d(9)): mild thirst | Vitals: BP 128/82, HR 76
        - \(d(7)): no notable symptoms (good day, walked 30 min) | Vitals: HR 77, Weight 82.0
        - \(d(6)): headache, insomnia, fatigue, stress
        - \(d(5)): no notable symptoms (good day, slept well) | Vitals: Weight 81.8
        - \(d(3)): high blood pressure, elevated heart rate, stress | Vitals: BP 134/86, HR 84
        - \(d(2)): dizziness, lightheadedness, elevated heart rate | Vitals: HR 86
        - \(d(1)): fatigue, elevated heart rate, dizziness | Vitals: HR 88, Weight 81.3

        ## Medications
        - Metformin 500mg — 2× daily (07:00, 19:00) with meals — started \(d(12)) — active
        - Glipizide 5mg — 1× daily (07:00, 30 min before first meal) — started \(d(8)) — active
        - Amlodipine 5mg — 1× daily (21:00) — started \(d(12)) — active

        ## Doctor Notes & Follow-ups
        - \(d(13)): HbA1c 8.2%, fasting glucose 168 mg/dL — Type 2 Diabetes confirmed. Starting Metformin 500mg and Amlodipine 5mg. Follow-up in 1 week.
        - \(d(8)): HbA1c improved to 7.4%, glucose 132 mg/dL. Treatment responding well. Adding Glipizide 5mg. Follow-up in 6 weeks.
        - \(d(4)): ED visit — COVID/influenza/dengue all negative. CBC: Monosit elevated (15.4%, 0.93×10³), Limfosit mildly low (21.5%), RBC slightly high (5.6). Consistent with resolving viral illness. Continue diabetes medications. Hydration advised.

        ## Flagged Abnormals
        - \(d(13)) HbA1c: 8.2% (normal: <5.7%) — from checkup
        - \(d(13)) Fasting Glucose: 168 mg/dL (normal: 70–99 mg/dL) — from checkup
        - \(d(13)) LDL Cholesterol: 142 mg/dL (normal: <100 mg/dL) — from checkup
        - \(d(13)) Triglycerides: 198 mg/dL (normal: <150 mg/dL) — from checkup
        - \(d(8)) HbA1c: 7.4% (normal: <5.7%) — from checkup (improving)
        - \(d(8)) LDL Cholesterol: 138 mg/dL (normal: <100 mg/dL) — from checkup
        - \(d(4)) Eritrosit (RBC): 5.6 juta/µL (normal: 4.5–5.5) — elevated, dehydration-possible — from ED checkup
        - \(d(4)) Limfosit Relatif: 21.5% (normal: 23–50%) — below range — from ED checkup
        - \(d(4)) Monosit Relatif: 15.4% (normal: 4–10%) — elevated — from ED checkup
        - \(d(4)) Monosit Absolut: 0.93 × 10³/µL (normal: 0.00–0.70) — elevated — from ED checkup

        ## Daily Summary Context
        **Last Generated:** \(ISO8601DateFormatter().string(from: daysAgo(1)))
        Patient with Type 2 Diabetes (diagnosed \(d(13))) and Stage 1 Hypertension, on Metformin, Glipizide, and Amlodipine. Blood sugar has improved well — HbA1c down from 8.2% to 7.4% and fasting glucose from 168 to 132 mg/dL in just over a week. Recent ED visit (\(d(4))) ruled out COVID/influenza/dengue; CBC showed elevated monocytes consistent with a resolving viral illness. Most recent concern: two consecutive days of dizziness with elevated heart rate (HR 86 → 88) and one elevated BP reading (134/86) — worth discussing with the doctor. Last entry logged \(d(1)).
        """
    }

    // MARK: - Checkup AI Analyses

    private static let checkupAnalysis1 = """
    ### Lab Analysis — Initial Diabetes Workup

    Your lab results indicate significantly elevated blood glucose and HbA1c, consistent with a new Type 2 Diabetes Mellitus diagnosis. Cholesterol values are also worth monitoring.

    **Flagged Markers**
    • 🔴 HbA1c: 8.2% (normal: <5.7%) — Indicates poor blood sugar control over the past 2–3 months. Values above 6.5% confirm diabetes.
    • 🔴 Fasting Glucose: 168 mg/dL (normal: 70–99 mg/dL) — Significantly above normal. Diagnostic for diabetes.
    • ⚠️ LDL Cholesterol: 142 mg/dL (normal: <100 mg/dL) — Elevated; increases cardiovascular risk which is already higher in diabetes.
    • ⚠️ Triglycerides: 198 mg/dL (normal: <150 mg/dL) — Borderline high; often elevated alongside insulin resistance.
    • ⚠️ Blood Pressure: 134/86 mmHg (normal: <120/80) — Stage 1 hypertension, common in Type 2 diabetes. Requires monitoring.

    **Recommendations**
    • Begin prescribed medication regimen (Metformin) exactly as directed. Take with meals to reduce GI side effects.
    • Significantly reduce refined carbohydrates, sugary drinks, and white rice. Prioritise vegetables, legumes, and lean protein.
    • Aim for 30 minutes of moderate-intensity walking at least 5 days per week.
    • If home glucose monitoring is available, check fasting blood sugar each morning and log the results.
    • Follow up in 2–3 weeks to reassess. Ask doctor about adding blood pressure medication if BP remains elevated.

    **Note:** This analysis is observational and not a substitute for medical advice. Always follow your doctor's instructions.
    """

    private static let checkupAnalysis2 = """
    ### Lab Analysis — Follow-up

    Your results show meaningful improvement since starting Metformin and dietary changes. Blood sugar control is trending in the right direction.

    **Flagged Markers**
    • ⚠️ HbA1c: 7.4% (normal: <5.7%) — Improved from 8.2% — a 0.8% drop this quickly is excellent progress. Still above target but heading the right way.
    • ⚠️ Fasting Glucose: 132 mg/dL (normal: 70–99 mg/dL) — Down from 168 mg/dL. Still elevated but noticeably better.
    • ⚠️ LDL Cholesterol: 138 mg/dL (normal: <100 mg/dL) — Slightly improved. Dietary changes are helping.

    **Positive Trends**
    • Blood sugar reduction of 21% in 2 weeks — medication and lifestyle changes are working.
    • Triglycerides trending down (not re-tested but dietary improvements should reflect next time).

    **Recommendations**
    • Continue current medication regimen. Doctor may consider adding a second agent (e.g. Glipizide) to accelerate progress.
    • Maintain dietary discipline — the results confirm it is making a real difference.
    • Monitor for hypoglycemia symptoms (shakiness, sweating, confusion) if medication is adjusted.
    • Keep walking habit — cardiovascular health is closely linked to glucose management.
    • Ask about LDL management at next visit — a statin may be considered if diet alone is insufficient.

    **Note:** This analysis is observational and not a substitute for medical advice.
    """

    private static let checkupAnalysis3 = """
    ### Lab Analysis — Emergency Department Panel

    Comprehensive blood panel and rapid infection screening performed at Mayapada Hospital Emergency Department following acute dizziness and general malaise.

    **Rapid Infection Panel — All Negative**
    • ✅ SARS-CoV-2 (COVID-19): Negative
    • ✅ Influenza A: Negative
    • ✅ Influenza B: Negative
    • ✅ Dengue NS1 Antigen: Negative

    **Hematology — Complete Blood Count (CBC)**
    • ✅ Hemoglobin (Hb): 16.4 g/dL (normal: 14.0–18.0) — Normal; no anemia
    • ✅ Hematokrit (Ht): 50% (normal: 40–52%) — Normal
    • ⚠️ Eritrosit (RBC): 5.6 juta/µL (normal: 4.5–5.5) — Mildly elevated; consistent with relative dehydration
    • ✅ MCV / MCH / MCHC: All within normal limits — no morphological red cell abnormality
    • ✅ Leukosit (WBC): 6.0 ribu/µL (normal: 4.3–10.8) — Normal; no acute bacterial infection signal
    • ⚠️ Limfosit Relatif: 21.5% (normal: 23–50%) — Mildly low; typically seen following recent viral illness
    • ⚠️ Monosit Relatif: 15.4% (normal: 4–10%) — Elevated; indicates active immune response
    • ⚠️ Monosit Absolut: 0.93 × 10³/µL (normal: 0.00–0.70) — Elevated alongside relative monocytosis
    • ✅ Trombosit: 172 × 10³/µL (normal: 150–400) — Normal
    • ✅ Retikulosit: 1.1% (normal: 0.5–1.5) — Normal bone marrow response

    **Assessment**
    All rapid infectious panels returned negative, ruling out COVID-19, influenza, and dengue as causes of the current symptoms. The CBC shows a pattern of elevated monocytes with mildly reduced lymphocytes — a profile consistent with a resolving viral illness, immune activation following physiological stress, or an early non-specific inflammatory response.

    The total WBC count is normal, which is reassuring and argues against active bacterial infection. The mildly elevated RBC may reflect reduced fluid intake; this is clinically relevant as dehydration worsens glycemic control in diabetes patients.

    **Recommendations**
    • Maintain hydration at 2.5–3 litres of water daily — poor hydration elevates blood viscosity and blood glucose
    • Continue all diabetes medications (Metformin, Glipizide, Amlodipine) without interruption
    • The dizziness may be multifactorial: dehydration, medication-related BP fluctuation, or residual post-viral fatigue
    • If monocytosis persists, fever returns, or dizziness worsens — request CRP and ESR for inflammatory markers
    • Planned diabetes follow-up in 6 weeks remains appropriate; include kidney function (creatinine, eGFR) and full lipid panel

    **Note:** This analysis is observational and not a substitute for medical advice. All interpretation should be confirmed with your treating physician.
    """
}
