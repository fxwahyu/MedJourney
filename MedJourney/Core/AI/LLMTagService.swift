//
//  LLMTagService.swift
//  MedJourney
//
//  Core/AI — Generates smart health tags + checkup analysis from journal entries.
//
//  Provider-agnostic: this service only builds prompts and parses responses.
//  Every network call is routed through `LLMGateway`, which decides the actual
//  provider (Groq → Gemini fallback). To change provider, edit LLMGateway only.
//

import Foundation

/// Builds the tagging / checkup-analysis prompts and parses the result.
/// All LLM calls go through `LLMGateway` (currently Groq, with Gemini fallback).
final class LLMTagService: AITagServiceProtocol {

    init() {}

    // MARK: - Public

    func generateTags(for entry: JournalEntry, ocrText: String? = nil) async throws -> AITagResult {
        let prompt = buildPrompt(for: entry, ocrText: ocrText)
        let raw = try await callGemini(prompt: prompt, isCheckup: entry.entryType == .checkup)

        if entry.entryType == .checkup {
            return parseJSON(from: raw)
        } else {
            return AITagResult(tags: parseTags(from: raw), analysis: nil)
        }
    }

    // MARK: - Prompt Building

    private func buildPrompt(for entry: JournalEntry, ocrText: String?) -> String {
        var lines: [String] = []

        switch entry.entryType {

        case .journal:
            lines.append("You are a health data assistant. Extract ONLY the symptoms the user actually experienced from this journal entry.")
            lines.append("Return ONLY a comma-separated list of 1-5 short symptom tags. No explanation.")
            lines.append("")
            lines.append("TAG FORMAT — follow exactly:")
            lines.append("- Each tag is a plain, human-readable symptom in everyday English (e.g. 'headache', 'fatigue', 'dizziness', 'nausea', 'blurry vision', 'insomnia', 'stress', 'anxiety').")
            lines.append("- Use spaces, NOT hyphens (write 'blurry vision', never 'blurry-vision').")
            lines.append("- Lowercase, 1-3 words each.")
            lines.append("")
            lines.append("WHAT COUNTS AS A SYMPTOM (include these):")
            lines.append("- Physical symptoms: headache, nausea, dizziness, fatigue, blurry vision, sore throat, stomach cramp, back pain, lightheadedness, etc.")
            lines.append("- Mental/sleep states: stress, anxiety, insomnia, poor sleep, low energy.")
            lines.append("- Abnormal vitals only (skip normal values): high blood pressure (systolic >140 or diastolic >90), elevated heart rate (>100 bpm), fever (>37.5°C), low temperature (<36°C).")
            lines.append("")
            lines.append("DO NOT INCLUDE (these are NOT symptoms):")
            lines.append("- Activities or habits: exercise, walking, hydration, diet.")
            lines.append("- Status/meta words: monitoring, routine, improving, concern, progress, positive, management, adherence, reminder.")
            lines.append("- Medication names or events, appointments, or anything that is not a felt symptom.")
            lines.append("- Diagnoses or disease names (e.g. write 'high blood pressure', never 'hypertension'; 'headache', never 'migraine').")
            lines.append("")
            lines.append("If the entry describes a good day with no symptoms, return an empty list.")
            lines.append("")
            lines.append("Entry data:")
            lines.append("Mood: \(entry.title)")
            if !entry.content.isEmpty {
                lines.append("Description: \(entry.content)")
            }
            if let bp = entry.bloodPressure { lines.append("Blood pressure: \(bp) mmHg") }
            if let hr = entry.heartRate     { lines.append("Heart rate: \(hr) bpm") }
            if let temp = entry.temperature { lines.append("Temperature: \(temp)°C") }

        case .checkup:
            lines.append("""
            You are MedCare AI, a health companion helping a patient understand their checkup results in plain, caring language.
            Analyze the entry below and return a valid JSON object with this exact schema:

            {
              "tags": ["string", "string"],
              "sections": [
                {
                  "heading": "Section Title",
                  "items": ["string", "string"]
                }
              ]
            }

            #1 RULE — BE CONCRETE AND SPECIFIC, NEVER GENERIC:
            - This analysis MUST be tailored to THIS patient's actual numbers. Generic advice that could apply to anyone is a FAILURE.
            - Quote the patient's REAL measured values and their reference ranges (e.g. "Your hemoglobin was 11.2 g/dL, below the 13.5–17.5 reference range").
            - Every suggestion and watch-symptom must connect to a SPECIFIC abnormal finding. Tie the advice to the marker.
            - BANNED generic filler unless directly tied to a specific finding: "maintain a balanced diet", "stay hydrated", "regular exercise and adequate sleep", "eat nutrient-rich foods", "monitor your health", "contact your provider if you notice unusual symptoms". If you would write one of these, replace it with something specific to an actual number.
            - Focus on the markers that are OUTSIDE the reference range. Lead with what matters most. Briefly note normal results, don't pad with them.

            SAFETY (stay non-diagnostic, but stay specific):
            - Describe what the numbers show observationally — do NOT name a disease or say "you have [condition]".
              Good: "Your fasting glucose of 168 mg/dL is well above the 70–99 range; persistently high readings like this are worth discussing with your doctor soon." (specific, actionable, no diagnosis)
              Bad: "Your glucose was a bit high. Maintain a balanced diet." (vague, generic)
            - You MAY explain what a marker measures and why an out-of-range value matters in plain terms, and give concrete diet/lifestyle steps known to influence THAT marker — without prescribing medication or dosage.
            - Frame abnormal results as "worth discussing with your doctor" and encourage professional follow-up where relevant.

            FORMATTING:
            - "tags": 3 to 6 short observational tags naming the actual findings (e.g. "Hemoglobin 11.2 (low)", "Glucose 168 (high)", "BP normal").
            - "sections": each has "heading" (plain text) and "items" (array of strings, one sentence each, ending with a period).
            - No markdown symbols (###, **, *, -) inside any string value.

            Use EXACTLY these section headings in this order. If a section has nothing specific to say, give it ONE honest item rather than generic filler:
            1. "Overview" — 1 to 3 sentences of PLAIN-LANGUAGE big picture. Absolutely NO numbers, units, or reference ranges here. Say in everyday words whether things look mostly fine, mixed, or concerning, and name the general areas involved (e.g. "Your blood count looks healthy overall, with one mild flag in your white cells worth keeping an eye on."). This is the TL;DR — do not list individual readings.
            2. "What Your Results Show" — this is the ONLY section with numbers. Go marker by marker for the notable ones. For EACH: state the actual value with units, the reference range, whether it is below/within/above it, AND clearly say what that means for safety — e.g. "safe / normal", "mildly out of range, usually not urgent", or "notably out of range, worth discussing with your doctor". Make the safe-vs-concerning verdict explicit for every marker. Prioritise out-of-range markers first.
            3. "Good Questions for Your Doctor" — pointed questions tied to THIS patient's specific out-of-range values (name the marker in the question).
            4. "Things That May Help" — concrete diet/lifestyle steps that specifically target the abnormal markers found (e.g. for high glucose: cut sugary drinks and refined carbs; for low iron/hemoglobin: iron-rich foods like red meat, spinach, lentils). Each item must reference which finding it helps.
            5. "Daily Care Ideas" — specific, trackable self-care steps relevant to the findings (e.g. "Log your fasting glucose each morning", "Note any dizziness episodes with the time of day").
            6. "Symptoms to Watch For" — SPECIFIC symptoms linked to the actual abnormal markers (e.g. for high glucose: excessive thirst, frequent urination, blurry vision; for low hemoglobin: unusual fatigue, shortness of breath, pale skin). Not generic "unusual symptoms".
            """)

            lines.append("")
            lines.append("Patient entry data:")
            if !entry.title.isEmpty   { lines.append("Title: \(entry.title)") }
            if !entry.content.isEmpty { lines.append("Notes: \(entry.content)") }
            if let bp   = entry.bloodPressure { lines.append("Blood pressure: \(bp) mmHg") }
            if let hr   = entry.heartRate     { lines.append("Heart rate: \(hr) bpm") }
            if let temp = entry.temperature   { lines.append("Temperature: \(temp)°C") }
            if let ocrText, !ocrText.isEmpty  {
                lines.append("")
                lines.append("Scanned document text:")
                lines.append(ocrText)
            }

        case .medication:
            return ""
        }
        
        return lines.joined(separator: "\n")
    }

    // MARK: - LLM Call (routes through the single gate)

    /// Sends the prompt through the app-wide `LLMGateway` — no direct provider calls.
    /// The provider/model/fallback order is decided entirely inside `LLMGateway`.
    private func callGemini(prompt: String, isCheckup: Bool) async throws -> String {
        guard !prompt.isEmpty else { return "" }
        print("✨ [LLMTagService] Routing tag generation through LLMGateway. Prompt length: \(prompt.count)")
        do {
            // Checkup tagging needs strict JSON; journal tagging is plain comma-separated text.
            return try await LLMGateway.shared.complete(prompt: prompt, jsonMode: isCheckup)
        } catch let error as LLMGatewayError {
            throw error.asAITagError
        }
    }

    // MARK: - JSON Parsing

    private func parseJSON(from raw: String) -> AITagResult {
        guard
            let data = raw.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            // Fallback: treat as plain comma-separated tags
            return AITagResult(tags: parseTags(from: raw), analysis: nil)
        }

        // ── Tags ──────────────────────────────────────────────────────────────
        let tags = json["tags"] as? [String] ?? []

        // ── Sections → formatted markdown string ─────────────────────────────
        var markdownParts: [String] = []

        if let sections = json["sections"] as? [[String: Any]] {
            for section in sections {
                guard
                    let heading = section["heading"] as? String,
                    let items   = section["items"]   as? [String]
                else { continue }

                // Section heading
                markdownParts.append("### \(heading)")

                // Each item becomes its own bullet, separated by a blank line for breathing room
                for item in items where !item.trimmingCharacters(in: .whitespaces).isEmpty {
                    markdownParts.append("• \(item.trimmingCharacters(in: .whitespaces))")
                }

                // Blank line between sections
                markdownParts.append("")
            }
        }

        // If the model returned old-style flat "analysis" array as fallback
        if markdownParts.isEmpty {
            if let analysisArray = json["analysis"] as? [String] {
                markdownParts = analysisArray.map { $0.trimmingCharacters(in: .whitespaces) }
            } else if let analysisStr = json["analysis"] as? String {
                markdownParts = [analysisStr]
            }
        }

        let analysisString = markdownParts
            .joined(separator: "\n")   // one newline between every item
            .trimmingCharacters(in: .whitespacesAndNewlines)

        print("✨ [LLMTagService] Parsed \(tags.count) tags and \(markdownParts.count) lines of analysis.")
        return AITagResult(tags: tags, analysis: analysisString.isEmpty ? nil : analysisString)
    }

    private func parseTags(from raw: String) -> [String] {
        raw.split(separator: ",")
            .map  { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .map  { $0.trimmingCharacters(in: CharacterSet(charactersIn: "\"'")) }
            .filter { !$0.isEmpty }
            .prefix(6)
            .map  { String($0) }
    }
}
