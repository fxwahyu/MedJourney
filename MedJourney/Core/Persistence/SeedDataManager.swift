// SeedDataManager.swift
// MedJourney — Demo seed data for video showcase
//
// Seeds 35 days of a realistic Type 2 diabetes patient journey into SwiftData
// and the health_summary.md file. Runs once on first launch (gated by UserDefaults).
// After seeding, opens the app directly to the main view (bypasses onboarding).
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

    private static let seedKey = "medjourney_demo_seed_v1"

    // MARK: - Entry Point

    static func seedIfNeeded(context: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: seedKey) else { return }

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
                daysAgo(32)   // started May 8
            ),
            (
                "Glipizide 5mg",
                "Take 30 minutes before first meal. Stimulates pancreas to release insulin. Do not skip meals after taking.",
                "07:00",
                daysAgo(19)   // started May 21
            ),
            (
                "Amlodipine 5mg",
                "Take before bed. Controls blood pressure. Do not take with grapefruit juice.",
                "21:00",
                daysAgo(32)   // started May 8
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
            // Day 1 — May 5 (35 days ago)
            j(daysBack: 35, hour: 22, min: 10,
              title: "Tired",
              content: "I've been drinking water non-stop today but still feel parched. Had to use the bathroom maybe 7 or 8 times. Also felt unusually tired after lunch even though I didn't do anything strenuous. Google says excessive thirst can be a diabetes symptom — going to book a doctor appointment tomorrow.",
              discomfort: 3,
              tags: "excessive-thirst,frequent-urination,fatigue,unexplained-tiredness"),

            // Day 2 — May 6
            j(daysBack: 34, hour: 21, min: 30,
              title: "Anxious",
              content: "Managed to get an appointment for tomorrow morning. Still very thirsty and tired. Also noticed my vision was a bit blurry after dinner, which is unusual for me. Going to mention all of this to the doctor. Trying not to overthink it but I'm a bit worried.",
              discomfort: 3,
              tags: "fatigue,blurry-vision,health-concern,doctor-appointment"),

            // Day 3 — May 7 - CHECKUP 1
            j(daysBack: 33, hour: 10, min: 45,
              title: "Blood test results — diabetes confirmed",
              content: "Doctor ordered a fasting blood glucose and HbA1c. Results came back in the afternoon. HbA1c is 8.2% and fasting glucose is 168 mg/dL — both significantly elevated. Doctor confirmed Type 2 Diabetes diagnosis. Also found LDL slightly high at 142. Will be prescribed medication. Feeling shocked and scared right now.",
              tags: "HbA1c-elevated,glucose-high,cholesterol-borderline,diabetes-type2-diagnosed,hypertension-stage1",
              type: .checkup,
              analysis: checkupAnalysis1,
              id: c1),

            // Day 4 — May 8
            j(daysBack: 32, hour: 9, min: 15,
              title: "Started Metformin and Amlodipine",
              content: "Picked up prescriptions this morning. Starting Metformin 500mg twice a day with meals, and Amlodipine 5mg at night for blood pressure. Pharmacist explained possible nausea from Metformin in the first few weeks and told me to always take it with food. Feeling nervous about all this but trying to stay positive. Going to make dietary changes too — cutting out rice at dinner and avoiding sugary drinks.",
              tags: "metformin-started,amlodipine-started,diabetes-management,medication-initiation,lifestyle-change",
              type: .medication),

            // Day 5 — May 9
            j(daysBack: 31, hour: 20, min: 0,
              title: "Sick",
              content: "Woke up feeling queasy this morning. Took Metformin with breakfast like I was told but still got nauseated within an hour. Had to sit down at work. Skipped my mid-morning coffee, which helped a bit. Dinner was hard to eat. BP seems okay. Hoping this side effect passes soon as the pharmacist said it usually does within 1-2 weeks.",
              discomfort: 5,
              bp: "126/82", hr: 78,
              tags: "nausea,medication-side-effect,metformin-adjustment,reduced-appetite"),

            // Day 6 — May 10
            j(daysBack: 30, hour: 21, min: 0,
              title: "Sick",
              content: "Another rough morning with the nausea. Managed to eat a small breakfast before taking the pill which helped slightly. Drank ginger tea throughout the day. Felt okay by afternoon. Still going to the bathroom frequently but maybe slightly less than before. The tiredness is still there. Really hope this medication adjustment period is short.",
              discomfort: 4,
              tags: "nausea,morning-sickness,fatigue,loss-of-appetite,adaptation"),

            // Day 7 — May 11
            j(daysBack: 29, hour: 20, min: 30,
              title: "Tired",
              content: "Nausea seems to be letting up a bit today. Managed a full breakfast without feeling terrible afterward. Went for a short 15-minute walk in the evening which helped my mood. Tracking calories and trying to eat more vegetables and less refined carbs. Weight at 82.5 kg today — was 83.2 a few weeks ago so small progress. Heart rate seems normal.",
              discomfort: 2,
              hr: 76, weight: 82.5,
              tags: "fatigue,diet-adjustment,diabetes-monitoring,weight-tracking,exercise"),

            // Day 8 — May 12
            j(daysBack: 28, hour: 21, min: 15,
              title: "Neutral",
              content: "No major complaints today. Took both medications on time. Still trying to drink 8 glasses of water a day — the thirst is less intense than it was two weeks ago which I take as a good sign. Blood pressure reading was normal. Meal plan is getting easier to follow. Work was busy so didn't have time to dwell on things.",
              discomfort: 2,
              bp: "128/82", hr: 76,
              tags: "hydration,routine-monitoring,blood-pressure-normal,improving"),

            // Day 9 — May 13
            j(daysBack: 27, hour: 22, min: 0,
              title: "Pain",
              content: "Had a pounding headache starting around 3pm. Took paracetamol and it helped within an hour. Not sure if it's related to the medication or just dehydration — I didn't drink enough water today. No other unusual symptoms. Going to bed early to rest. Will make sure to drink more water tomorrow.",
              discomfort: 4,
              tags: "headache,dehydration-possible,fatigue,afternoon-crash"),

            // Day 10 — May 14
            j(daysBack: 26, hour: 20, min: 45,
              title: "Tired",
              content: "Energy levels are better than the first week but still not back to normal. Had a good lunch which helped in the afternoon. Heart rate is normal. Temperature is fine. No nausea today which is a relief. Starting to understand what foods spike my energy and what keeps me steady — rice and sweet drinks are definitely out.",
              discomfort: 3,
              hr: 80, temp: 36.6,
              tags: "low-energy,fatigue,routine-monitoring,dietary-awareness"),

            // Day 11 — May 15
            j(daysBack: 25, hour: 21, min: 30,
              title: "Tired",
              content: "Felt unusually thirsty again today, especially after lunch. Not as bad as the first week but noticeable. Checked blood pressure — slightly elevated at 132/85. Going to mention this at the next check-up. Also felt a bit lightheaded standing up quickly, which I read can be from Amlodipine. Will monitor this.",
              discomfort: 3,
              bp: "132/85",
              tags: "excessive-thirst,elevated-blood-pressure,dizziness-postural,diabetes-symptom,monitoring"),

            // Day 12 — May 16
            j(daysBack: 24, hour: 19, min: 0,
              title: "Good",
              content: "Went for a 30-minute walk with my wife this evening. Felt genuinely good afterward — both physically and mentally. Weight is 82.2 kg. Heart rate was up slightly during the walk but that's expected. Managing diet is becoming a habit now. Less stressed about the diagnosis than I was in the first week. Doctor follow-up next week.",
              discomfort: 2,
              hr: 77, weight: 82.2,
              tags: "exercise,weight-management,improved-mood,diabetes-management"),

            // Day 13 — May 17
            j(daysBack: 23, hour: 21, min: 0,
              title: "Sick",
              content: "While reading after dinner, my vision went blurry for about 20 minutes. It cleared on its own but it was unsettling. I know blurry vision can be a sign of high blood sugar. Did not take any extra medication — just drank water and rested. Going to mention this to the doctor at the monthly check-up on the 20th. No other major symptoms today.",
              discomfort: 4,
              tags: "blurry-vision,diabetes-symptom,eye-concern,glucose-fluctuation"),

            // Day 14 — May 18
            j(daysBack: 22, hour: 21, min: 30,
              title: "Neutral",
              content: "No blurry vision today. Took medications on time. BP reading looks good. Had my first full energy day since starting treatment — managed a full day of work without the afternoon crash. Dinner was grilled chicken and salad, feeling good about my food choices. Still avoiding rice and sugar.",
              discomfort: 2,
              bp: "126/82",
              tags: "improving,blood-pressure-normal,energy-improving,dietary-adherence"),

            // Day 15 — May 19
            j(daysBack: 21, hour: 20, min: 0,
              title: "Good",
              content: "Nothing unusual today. Took all three medications on schedule. Did a 20-minute evening walk. Feeling more in control of things. Looking forward to the monthly check-up tomorrow to see if the numbers have improved. Going to bed at a reasonable time to try and maintain a good sleep schedule.",
              discomfort: 1,
              tags: "routine,exercise,diabetes-management,positive-outlook"),

            // Day 16 — May 20 - CHECKUP 2
            j(daysBack: 20, hour: 11, min: 0,
              title: "Monthly check-up — blood sugar improving",
              content: "Great news from the doctor today. HbA1c dropped from 8.2% to 7.4%, and fasting glucose is down to 132 mg/dL. Doctor says the Metformin is working and the dietary changes are helping. LDL is still borderline at 138 but trending down. Doctor wants to add Glipizide 5mg to accelerate the improvement. Overall feeling encouraged.",
              tags: "HbA1c-improving,glucose-decreasing,cholesterol-borderline,treatment-responding,progress",
              type: .checkup,
              analysis: checkupAnalysis2,
              id: c2),

            // Day 17 — May 21
            j(daysBack: 19, hour: 9, min: 30,
              title: "Started Glipizide 5mg",
              content: "Doctor added Glipizide 5mg to my regimen, to be taken 30 minutes before my first meal. Pharmacist warned me not to skip meals after taking it since it can cause hypoglycemia. I now have three medications to manage: Metformin morning and evening, Glipizide before breakfast, and Amlodipine at night. Setting alarms for all of them. Feeling hopeful.",
              tags: "glipizide-started,combination-therapy,medication-complexity,improving,hopeful",
              type: .medication),

            // Day 18 — May 22
            j(daysBack: 18, hour: 20, min: 0,
              title: "Sick",
              content: "Took Glipizide 30 minutes before breakfast as instructed. Within two hours I felt slightly dizzy and lightheaded. Ate a small snack and it passed. Blood pressure was normal so it's probably hypoglycemia from the medication kicking in. Heart rate was a bit low at 74. Going to make sure I eat a proper breakfast every time I take it.",
              discomfort: 4,
              bp: "128/84", hr: 74,
              tags: "dizziness,glipizide-side-effect,possible-hypoglycemia,medication-adjustment"),

            // Day 19 — May 23
            j(daysBack: 17, hour: 21, min: 0,
              title: "Good",
              content: "No dizziness today. Made sure to eat a proper breakfast before the Glipizide kicked in. Energy levels were noticeably better in the afternoon compared to last week. Managed a meeting that ran two hours without feeling drained. Small win. Hydration was good today. No unusual symptoms.",
              discomfort: 1,
              tags: "improved-energy,medication-tolerating,routine-monitoring,positive"),

            // Day 20 — May 24
            j(daysBack: 16, hour: 22, min: 30,
              title: "Pain",
              content: "Didn't sleep well last night — woke up around 2am and couldn't fall back asleep until 5am. Woke up with a headache that lasted most of the morning. No idea what caused the insomnia. Could be stress at work or just my body adjusting. Took it easy today. No other unusual symptoms. Going to try a decaf evening routine.",
              discomfort: 5,
              tags: "headache,insomnia,sleep-disturbance,work-stress,fatigue"),

            // Day 21 — May 25
            j(daysBack: 15, hour: 21, min: 0,
              title: "Tired",
              content: "Slept terribly again. I fell asleep fine but kept waking up. Felt exhausted all day. Heart rate was slightly elevated, probably from the poor sleep. Temperature is normal. Going to avoid any screen time after 9pm and try warm milk before bed. If this continues I'll mention it to the doctor.",
              discomfort: 5,
              hr: 82, temp: 36.8,
              tags: "insomnia,fatigue,elevated-heart-rate,sleep-disturbance,monitoring"),

            // Day 22 — May 26
            j(daysBack: 14, hour: 19, min: 30,
              title: "Good",
              content: "Finally slept well last night. Woke up refreshed for the first time in a while. Weighed myself and I'm at 81.8 kg — that's 1.4 kg less than when I started. Going for a walk felt easier today. Diet has been consistent for 2+ weeks now. Mood is much better when I have energy.",
              discomfort: 1,
              weight: 81.8,
              tags: "weight-loss,diet-success,good-sleep,positive-outlook,exercise"),

            // Day 23 — May 27
            j(daysBack: 13, hour: 21, min: 0,
              title: "Pain",
              content: "Sat at my desk for most of the day and developed lower back pain by the afternoon. This is not diabetes-related — I just have bad posture when working from home. Used a heating pad and did some stretches. BP was normal when I checked. Not a major concern but I should set a reminder to stand up every hour.",
              discomfort: 4,
              bp: "130/83",
              tags: "back-pain,musculoskeletal,desk-work,posture,non-diabetes-related"),

            // Day 24 — May 28
            j(daysBack: 12, hour: 21, min: 30,
              title: "Sick",
              content: "Had a big family dinner with fried food and I think I overdid it. Stomach cramp started around 9pm and I felt bloated for hours. Classic Metformin + fatty food reaction. Lesson learned — I need to be more careful even at family events. No other symptoms. Going to stick to smaller portions and avoid fried foods consistently.",
              discomfort: 4,
              tags: "stomach-cramp,bloating,dietary-indiscretion,metformin-reaction,lesson-learned"),

            // Day 25 — May 29
            j(daysBack: 11, hour: 20, min: 0,
              title: "Neutral",
              content: "Stomach is fine today, back to normal eating. BP looked good at 128/84. Took all medications on time. Did a 25-minute walk. Nothing unusual to report. My appetite is finally stabilising and I'm finding a rhythm with the new diet. Drinking herbal tea in the evenings instead of the usual sweet drinks.",
              discomfort: 1,
              bp: "128/84",
              tags: "blood-pressure-stable,routine-monitoring,dietary-adherence,improving"),

            // Day 26 — May 30
            j(daysBack: 10, hour: 21, min: 0,
              title: "Sick",
              content: "Woke up with a sore throat and runny nose. Temperature is 37.4°C — low-grade fever. Not sure if this is a regular cold or something else. Took my regular medications and also some cold medicine. Blood sugar tends to rise when you have an infection so I'll need to monitor more carefully. Going to rest tomorrow.",
              discomfort: 4,
              temp: 37.4,
              tags: "sore-throat,fever-mild,cold-symptoms,infection-monitoring,glucose-risk"),

            // Day 27 — May 31
            j(daysBack: 9, hour: 22, min: 0,
              title: "Tired",
              content: "Busy morning and completely forgot to take Glipizide before breakfast. Only realised at noon. Decided not to take a late dose since I'd already eaten and the risk of hypoglycemia would be too high. Will set a louder alarm tomorrow. Cold symptoms are improving — sore throat is mostly gone. Just feeling a bit rundown.",
              discomfort: 2,
              tags: "missed-dose,medication-adherence,reminder-needed,cold-recovering"),

            // Day 28 — Jun 1
            j(daysBack: 8, hour: 21, min: 0,
              title: "Anxious",
              content: "Checked blood pressure this morning and it was 134/86 — the highest in a while. Heart rate was also slightly elevated at 84. Not sure if this is from missing the Glipizide yesterday or from residual stress. Took all medications correctly today. Will keep a closer eye on BP over the next few days. Going to take medication adherence more seriously.",
              discomfort: 3,
              bp: "134/86", hr: 84,
              tags: "elevated-blood-pressure,elevated-heart-rate,medication-effect,monitoring,adherence-reminder"),

            // Day 29 — Jun 2
            j(daysBack: 7, hour: 22, min: 0,
              title: "Anxious",
              content: "End of a really intense work week with multiple deadlines. I've been eating at my desk and not moving enough. Feeling tense through my shoulders and neck. No specific physical symptoms but the stress is noticeable. Will try to decompress this weekend. Medications taken on time. Going to try to relax more and maybe read instead of watching screens at night.",
              discomfort: 3,
              tags: "work-stress,tension,fatigue,sedentary-behavior,mental-health"),

            // Day 30 — Jun 3 - CHECKUP 3 (Emergency Department visit)
            j(daysBack: 6, hour: 11, min: 30,
              title: "ED visit — blood panel and infection screening",
              content: "After lingering cold symptoms and the dizziness from last week, my wife insisted I go to the emergency department. They ran a full blood count plus rapid panels for COVID-19, influenza, and dengue. Everything came back the same evening. All infection panels were negative. Blood work showed slightly elevated monocytes and mildly low lymphocytes — the doctor said this is consistent with a recent or resolving viral illness. RBC was a touch high which they attributed to possible mild dehydration. Relieved it's nothing more serious. Doctor advised to continue all diabetes medications without change and stay well hydrated. Will bring these results to my next diabetes follow-up.",
              tags: "ED-visit,infection-ruled-out,monocytes-elevated,lymphocytes-low,immune-response,dizziness-workup,dehydration-possible",
              type: .checkup,
              analysis: checkupAnalysis3,
              images: loadBundleImages(names: [("lab_page1", "jpg"), ("lab_page2", "jpg")]),
              id: c3),

            // Day 31 — Jun 4
            j(daysBack: 5, hour: 21, min: 0,
              title: "Tired",
              content: "Despite the good checkup results yesterday, physically I feel quite tired today. Heart rate is slightly elevated at 86. Weight is 81.5 kg — hasn't changed much in the last week. Probably just cumulative fatigue from the work stress and not sleeping consistently. Going to try to have an early night.",
              discomfort: 4,
              hr: 86, weight: 81.5,
              tags: "fatigue,elevated-heart-rate,weight-stable,cumulative-tiredness"),

            // Day 32 — Jun 5
            j(daysBack: 4, hour: 21, min: 30,
              title: "Pain",
              content: "Developed a headache after dinner that lasted about two hours. Took paracetamol and it helped. Blood pressure was 130/82 which is fine, so the headache is probably tension or dehydration again. Drank an extra glass of water before bed. No other unusual symptoms. Will try not to skip water during work hours tomorrow.",
              discomfort: 3,
              bp: "130/82",
              tags: "headache,blood-pressure-normal,dehydration-possible,tension"),

            // Day 33 — Jun 6
            j(daysBack: 3, hour: 20, min: 0,
              title: "Anxious",
              content: "Back-to-back meetings from 10am to 3pm. Completely forgot to eat lunch. By 4pm I was feeling very lightheaded and had to sit down. Ate a snack and recovered. Taking Glipizide without eating properly is dangerous and I need to be more careful. Set a non-dismissible 12pm alarm for lunch. Energy was fine by evening.",
              discomfort: 2,
              tags: "skipped-meal,hypoglycemia-risk,dizziness,busy-schedule,diet-disruption,glipizide-risk"),

            // Day 34 — Jun 7
            j(daysBack: 2, hour: 21, min: 0,
              title: "Sick",
              content: "Experienced a dizzy spell around 7pm out of nowhere. Had to hold the wall for a second. It passed quickly but left me feeling uneasy. No chest pain, no shortness of breath. Heart rate seemed a bit fast. I wonder if it's from the stress lately or something else. Going to take it easy tonight and check my BP in the morning.",
              discomfort: 5,
              tags: "dizziness,lightheadedness,concern,heart-rate-elevated,monitoring"),

            // Day 35 — Jun 8 (yesterday)
            j(daysBack: 1, hour: 20, min: 30,
              title: "Sick",
              content: "Woke up feeling okay but by the evening I had that same unsettled feeling as yesterday. Heart rate at 88 which is on the higher side for me. Weight stable. Going to measure BP tomorrow morning — I've been putting it off but after two days of dizziness I should check it. Took all medications on time. Mentioned the dizziness to my wife and she's also concerned. Will call the clinic if it continues.",
              discomfort: 4,
              hr: 88, weight: 81.3,
              tags: "fatigue,elevated-heart-rate,monitoring,dizziness-recurring,concern"),
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
        - Type 2 Diabetes Mellitus (diagnosed \(d(33)))
        - Hypertension Stage 1 (monitored, on Amlodipine)

        ## Lab Trends
        | Marker | Normal Range | Status |
        |--------|--------------|--------|
        | HbA1c | <5.7% | Improving: 8.2% → 7.4% → 7.1% |
        | Fasting Glucose | 70–99 mg/dL | Improving: 168 → 132 → 118 mg/dL |
        | LDL Cholesterol | <100 mg/dL | Borderline improving: 142 → 138 → 130 mg/dL |
        | Triglycerides | <150 mg/dL | Borderline: 198 mg/dL (last check) |
        | Blood Pressure | <120/80 mmHg | Monitored: typically 126–134/82–86 |

        ## Recent Journal Tags (last 30 entries max)
        - \(d(34)): fatigue, blurry-vision, health-concern, doctor-appointment
        - \(d(33)): HbA1c-elevated, glucose-high, cholesterol-borderline, diabetes-type2-diagnosed
        - \(d(32)): metformin-started, amlodipine-started, medication-initiation, lifestyle-change
        - \(d(31)): nausea, medication-side-effect, metformin-adjustment | Vitals: BP 126/82, HR 78
        - \(d(30)): nausea, morning-sickness, fatigue, loss-of-appetite
        - \(d(29)): fatigue, diet-adjustment, diabetes-monitoring | Vitals: HR 76
        - \(d(28)): hydration, routine-monitoring, blood-pressure-normal | Vitals: BP 128/82, HR 76
        - \(d(27)): headache, dehydration-possible, fatigue
        - \(d(26)): low-energy, fatigue, routine-monitoring | Vitals: HR 80, Temp 36.6
        - \(d(25)): excessive-thirst, elevated-blood-pressure, diabetes-symptom | Vitals: BP 132/85
        - \(d(24)): exercise, weight-management, improved-mood | Vitals: HR 77
        - \(d(23)): blurry-vision, diabetes-symptom, eye-concern
        - \(d(22)): improving, blood-pressure-normal | Vitals: BP 126/82
        - \(d(21)): routine, exercise, diabetes-management
        - \(d(20)): HbA1c-improving, glucose-decreasing, treatment-responding
        - \(d(19)): glipizide-started, combination-therapy, hopeful
        - \(d(18)): dizziness, glipizide-side-effect, possible-hypoglycemia | Vitals: BP 128/84, HR 74
        - \(d(17)): improved-energy, medication-tolerating, routine-monitoring
        - \(d(16)): headache, insomnia, sleep-disturbance
        - \(d(15)): insomnia, fatigue, elevated-heart-rate | Vitals: HR 82, Temp 36.8
        - \(d(14)): weight-loss, diet-success, good-sleep | Vitals: Weight 81.8
        - \(d(13)): back-pain, musculoskeletal, non-diabetes-related | Vitals: BP 130/83
        - \(d(12)): stomach-cramp, bloating, dietary-indiscretion
        - \(d(11)): blood-pressure-stable, routine-monitoring | Vitals: BP 128/84
        - \(d(10)): sore-throat, fever-mild, cold-symptoms | Vitals: Temp 37.4
        - \(d(9)): missed-dose, medication-adherence, cold-recovering
        - \(d(8)): elevated-blood-pressure, elevated-heart-rate, adherence-reminder | Vitals: BP 134/86, HR 84
        - \(d(7)): work-stress, tension, fatigue
        - \(d(6)): ED-visit, infection-ruled-out, monocytes-elevated, immune-response, dizziness-workup
        - \(d(5)): fatigue, elevated-heart-rate, weight-stable | Vitals: HR 86

        ## Medications
        - Metformin 500mg — 2× daily (07:00, 19:00) with meals — started \(d(32)) — active
        - Glipizide 5mg — 1× daily (07:00, 30 min before first meal) — started \(d(19)) — active
        - Amlodipine 5mg — 1× daily (21:00) — started \(d(32)) — active

        ## Doctor Notes & Follow-ups
        - \(d(33)): HbA1c 8.2%, fasting glucose 168 mg/dL — Type 2 Diabetes confirmed. Starting Metformin 500mg and Amlodipine 5mg. Follow-up in 2 weeks.
        - \(d(20)): HbA1c improved to 7.4%, glucose 132 mg/dL. Treatment responding. Adding Glipizide 5mg. Follow-up in 2 weeks.
        - \(d(6)): ED visit — COVID/influenza/dengue all negative. CBC: Monosit elevated (15.4%, 0.93×10³), Limfosit mildly low (21.5%), RBC slightly high (5.6). Consistent with resolving viral illness. Continue diabetes medications. Hydration advised.

        ## Flagged Abnormals
        - \(d(33)) HbA1c: 8.2% (normal: <5.7%) — from checkup
        - \(d(33)) Fasting Glucose: 168 mg/dL (normal: 70–99 mg/dL) — from checkup
        - \(d(33)) LDL Cholesterol: 142 mg/dL (normal: <100 mg/dL) — from checkup
        - \(d(33)) Triglycerides: 198 mg/dL (normal: <150 mg/dL) — from checkup
        - \(d(20)) HbA1c: 7.4% (normal: <5.7%) — from checkup (improving)
        - \(d(20)) LDL Cholesterol: 138 mg/dL (normal: <100 mg/dL) — from checkup
        - \(d(6)) Eritrosit (RBC): 5.6 juta/µL (normal: 4.5–5.5) — elevated, dehydration-possible — from ED checkup
        - \(d(6)) Limfosit Relatif: 21.5% (normal: 23–50%) — below range — from ED checkup
        - \(d(6)) Monosit Relatif: 15.4% (normal: 4–10%) — elevated — from ED checkup
        - \(d(6)) Monosit Absolut: 0.93 × 10³/µL (normal: 0.00–0.70) — elevated — from ED checkup

        ## Daily Summary Context
        **Last Generated:** \(ISO8601DateFormatter().string(from: daysAgo(1)))
        Recently noted: elevated-heart-rate, fatigue, dizziness-recurring, monitoring, concern, immune-response. Ongoing medication regimen with Metformin (morning/evening), Glipizide (morning before meal), Amlodipine (evening). Blood sugar has improved significantly over the past month. Recent ED visit (Jun 3) ruled out COVID/influenza/dengue; CBC showed elevated monocytes consistent with resolving viral illness. Two consecutive days of dizziness and elevated heart rate (HR 86–88) — consider discussing with doctor at next visit. Logged on \(d(1)).
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
    ### Lab Analysis — 2-Week Follow-up

    Your results show meaningful improvement since starting Metformin and dietary changes. Blood sugar control is trending in the right direction.

    **Flagged Markers**
    • ⚠️ HbA1c: 7.4% (normal: <5.7%) — Improved from 8.2% — a 0.8% drop in 2 weeks is excellent progress. Still above target but heading the right way.
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
