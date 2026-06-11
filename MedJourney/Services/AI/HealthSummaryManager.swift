//
//  HealthSummaryManager.swift
//  MedJourney
//
//  Services/AI — Owner of the curated `health_summary.md` context file.
//
//  This file is the heart of the token-efficient pipeline: raw journal entries and
//  checkup PDFs are NEVER sent to the cloud LLM on every call. Instead, each save
//  progressively updates this compact Markdown file, and ONLY this file (or a slice
//  of it) is sent as context. Achieves ~90% token reduction.
//
//  Implemented as an `actor` so all file I/O is serialized and thread-safe.
//
//  NOTE: This is an *additional* AI context layer. The raw entries and uploaded
//  files remain in the existing SwiftData / persistence layer — this never replaces
//  or duplicates that storage.
//

import Foundation

/// Thread-safe reader/writer for the per-user `health_summary.md` curated context file.
actor HealthSummaryManager {

    static let shared = HealthSummaryManager()

    /// Max journal tag lines retained in the MD file to prevent unbounded growth.
    private let maxJournalTagEntries = 30
    private let maxCheckupResults = 20

    /// On-disk location: `<Documents>/health_summary.md`.
    private let fileURL: URL

    /// In-memory cache of the file contents (loaded lazily, kept in sync on writes).
    private var cachedContent: String?

    init(fileName: String = "health_summary.md") {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.fileURL = docs.appendingPathComponent(fileName)
    }

    // MARK: - Public API

    /// Returns the full current Markdown summary, creating an empty scaffold if none exists.
    func getCurrentSummary() -> String {
        if let cached = cachedContent { return cached }
        let content = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? Self.emptyScaffold()
        cachedContent = content
        return content
    }

    /// Rough token estimate of the full file (≈ 4 chars per token).
    /// Used to verify the pipeline is staying within budget.
    func getSummaryTokenEstimate() -> Int {
        getCurrentSummary().count / 4
    }

    /// Returns a compact context slice for the home-screen greeting generator.
    ///
    /// Priority:
    ///  1. The explicit `## Daily Summary Context` section if it has real content
    ///     (written by `updateDailySummaryContext()` after each entry/checkup save).
    ///  2. A synthesised snapshot built from the populated journal-tag and checkup
    ///     sections — used when the explicit section hasn't been written yet (e.g.
    ///     seed data, first launch, or fresh install).
    ///  3. A fallback string so the LLM still gets *something*.
    func getDailySummaryContext() -> String {
        let content = getCurrentSummary()

        // 1. Prefer the explicit, pre-written context section.
        if let explicit = Self.extractSection(named: "Daily Summary Context", from: content),
           !explicit.isEmpty,
           !explicit.contains("No recent health context") {
            return explicit
        }

        // 2. Synthesise from the sections that ARE populated.
        var parts: [String] = []
        if let tags = Self.extractSection(named: "Recent Journal Tags", from: content),
           !tags.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append("Recent journal observations:\n\(tags)")
        }
        if let checkups = Self.extractSection(named: "Recent Checkup Results", from: content),
           !checkups.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append("Recent checkup results:\n\(checkups)")
        }
        if let flagged = Self.extractSection(named: "Flagged Abnormals", from: content),
           !flagged.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append("Flagged lab / vital results:\n\(flagged)")
        }
        if let notes = Self.extractSection(named: "Doctor Notes & Follow-ups", from: content),
           !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append("Doctor notes:\n\(notes)")
        }
        if let meds = Self.extractSection(named: "Medications", from: content),
           !meds.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append("Current medications:\n\(meds)")
        }

        guard !parts.isEmpty else { return "No recent health context available yet." }
        return parts.joined(separator: "\n\n")
    }

    /// Populates the MD file from an existing array of `JournalEntry` objects.
    ///
    /// Called at app launch when `health_summary.md` is empty (e.g. seed data was
    /// inserted directly into SwiftData, bypassing the normal `saveEntry` pipeline).
    /// Safe to call repeatedly — it only runs if the "Recent Journal Tags" section
    /// has fewer entries than what's in SwiftData.
    func bootstrapFromEntries(_ entries: [JournalEntry]) {
        let content = getCurrentSummary()
        let existingTags = Self.extractSection(named: "Recent Journal Tags", from: content) ?? ""
        let existingJournalCount = existingTags.components(separatedBy: "\n")
            .filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("-") }.count
        let existingCheckups = Self.extractSection(named: "Recent Checkup Results", from: content) ?? ""
        let existingCheckupCount = existingCheckups.components(separatedBy: "\n")
            .filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("-") }.count

        let journalEntries = entries.filter { $0.entryType == .journal }
        let checkupEntries = entries.filter { $0.entryType == .checkup }

        // Only bootstrap if the file has fewer rows than SwiftData for EITHER type.
        let needsJournal = existingJournalCount < journalEntries.count
        let needsCheckups = existingCheckupCount < checkupEntries.count
        guard needsJournal || needsCheckups else { return }

        var updated = content
        let dateFormatter: DateFormatter = {
            let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
        }()

        // Inject journal tag lines for entries that have aiTags, sorted oldest → newest.
        if needsJournal {
            for entry in journalEntries.sorted(by: { $0.createdAt < $1.createdAt }) {
                let tagPart = entry.aiTags.isEmpty
                    ? (entry.title.isEmpty ? "(no tags)" : entry.title)
                    : entry.aiTags.joined(separator: ", ")
                var vitals: [String] = []
                if let bp   = entry.bloodPressure { vitals.append("BP \(bp)") }
                if let temp = entry.temperature   { vitals.append("Temp \(temp)") }
                if let hr   = entry.heartRate     { vitals.append("HR \(hr)") }
                let vitalsPart = vitals.isEmpty ? "" : " | Vitals: \(vitals.joined(separator: ", "))"
                let line = "- \(dateFormatter.string(from: entry.createdAt)): \(tagPart)\(vitalsPart)"
                updated = Self.appendToSection(
                    named: "Recent Journal Tags (last 30 entries max)",
                    line: line,
                    in: updated,
                    cappedAt: maxJournalTagEntries
                )
            }
        }

        // Inject checkup result lines so checkup-only users still get a specific
        // briefing. Captures ALL markers (normal included) as a compact summary —
        // an all-normal panel should let the briefing say "your bloodwork looked healthy".
        if needsCheckups {
            for entry in checkupEntries.sorted(by: { $0.createdAt < $1.createdAt }) {
                let summary = entry.aiTags.isEmpty
                    ? "checkup logged"
                    : entry.aiTags.prefix(6).joined(separator: ", ")
                let line = "- \(dateFormatter.string(from: entry.createdAt)): \(summary)"
                updated = Self.appendToSection(
                    named: "Recent Checkup Results (last 20 max)",
                    line: line,
                    in: updated,
                    cappedAt: maxCheckupResults
                )
            }
        }

        updated = Self.touchLastUpdated(updated)
        persist(updated)
        print("📋 [HealthSummaryManager] Bootstrapped health_summary.md from \(journalEntries.count) journal + \(checkupEntries.count) checkup entries.")
    }

    /// Appends a compact journal summary line + tags to the file after a journal save.
    ///
    /// - The "Recent Journal Tags" section is capped at the last `maxJournalTagEntries`.
    /// - Vital-alert tags are also reflected into the running tag line.
    func updateFromJournalEntry(_ entry: JournalEntry, tags: [HealthTag]) {
        var content = getCurrentSummary()

        let dateStr = Self.isoDay(entry.createdAt)
        let tagLabels = tags.map(\.label)
        let tagPart = tagLabels.isEmpty ? entry.aiTags.joined(separator: ", ")
                                        : tagLabels.joined(separator: ", ")

        var vitals: [String] = []
        if let bp = entry.bloodPressure { vitals.append("BP \(bp)") }
        if let temp = entry.temperature { vitals.append("Temp \(temp)") }
        if let hr = entry.heartRate { vitals.append("HR \(hr)") }
        let vitalsPart = vitals.isEmpty ? "" : " | Vitals: \(vitals.joined(separator: ", "))"

        let newLine = "- \(dateStr): \(tagPart.isEmpty ? "(no tags)" : tagPart)\(vitalsPart)"

        content = Self.appendToSection(
            named: "Recent Journal Tags (last 30 entries max)",
            line: newLine,
            in: content,
            cappedAt: maxJournalTagEntries
        )
        content = Self.touchLastUpdated(content)
        persist(content)
    }

    /// Writes the *output* of a checkup analysis into the file: lab trends, flagged
    /// abnormals, and doctor notes. Raw OCR text is intentionally NOT stored here.
    func updateFromCheckupAnalysis(_ analysis: CheckupAnalysis) {
        var content = getCurrentSummary()
        let dateStr = Self.isoDay(analysis.date)

        // Flagged abnormals
        for marker in analysis.flaggedMarkers where marker.isAbnormal {
            let line = "- \(dateStr) \(marker.name): \(marker.value)\(marker.unit.isEmpty ? "" : " \(marker.unit)") (normal: \(marker.normalRange)) — from checkup"
            content = Self.appendToSection(named: "Flagged Abnormals", line: line, in: content, cappedAt: 50)
        }

        // Doctor notes / follow-ups (use the summary as the note)
        if !analysis.summary.isEmpty {
            let note = "- \(dateStr): \(analysis.summary)"
            content = Self.appendToSection(named: "Doctor Notes & Follow-ups", line: note, in: content, cappedAt: 30)
        }

        content = Self.touchLastUpdated(content)
        persist(content)
    }

    /// Replaces the "Daily Summary Context" section body with a freshly generated snapshot.
    /// Called by the pipelines after an entry/checkup is processed.
    func updateDailySummaryContext(_ snapshot: String) {
        var content = getCurrentSummary()
        let body = "**Last Generated:** \(Self.isoTimestamp(Date()))\n\(snapshot)"
        content = Self.replaceSectionBody(named: "Daily Summary Context", with: body, in: content)
        content = Self.touchLastUpdated(content)
        persist(content)
    }

    /// Feeds the curated MD file from a checkup result the *existing* live flow already
    /// produced (`LLMTagService` tags + Markdown `aiAnalysis`) — instead of running
    /// `LLMAnalysisService.analyzeCheckup` a second time. This keeps the live checkup
    /// pipeline byte-for-byte unchanged while still building the curated knowledge base.
    ///
    /// - Reflects out-of-range-sounding tags (e.g. "Hemoglobin below range") into
    ///   "Flagged Abnormals" using the same observational vocabulary the existing
    ///   prompts already produce.
    /// - Stores a short excerpt of the Markdown analysis as a "Doctor Notes & Follow-ups"
    ///   entry (never the raw OCR text — keeps the file compact).
    func updateFromExistingCheckupResult(tags: [String], analysisMarkdown: String?, date: Date) {
        var content = getCurrentSummary()
        let dateStr = Self.isoDay(date)

        let flagKeywords = ["below", "above", "elevated", "low ", "high ", "outside"]
        for tag in tags where flagKeywords.contains(where: { tag.lowercased().contains($0) }) {
            let line = "- \(dateStr) \(tag) — from checkup"
            content = Self.appendToSection(named: "Flagged Abnormals", line: line, in: content, cappedAt: 50)
        }

        // Always record a compact result summary (normal panels included) so the daily
        // briefing has something specific to reference even when nothing is flagged.
        if !tags.isEmpty {
            let summary = tags.prefix(6).joined(separator: ", ")
            content = Self.appendToSection(
                named: "Recent Checkup Results (last 20 max)",
                line: "- \(dateStr): \(summary)",
                in: content,
                cappedAt: maxCheckupResults
            )
        }

        if let analysisMarkdown, let excerpt = Self.firstPlainSentence(from: analysisMarkdown) {
            let note = "- \(dateStr): \(excerpt)"
            content = Self.appendToSection(named: "Doctor Notes & Follow-ups", line: note, in: content, cappedAt: 30)
        }

        content = Self.touchLastUpdated(content)
        persist(content)
    }

    /// Returns true when the MD file has no real journal or checkup data yet —
    /// i.e. the "Recent Journal Tags" section is empty. Used to decide whether to
    /// invalidate the DailySummaryService greeting cache after a bootstrap.
    func isEffectivelyEmpty() -> Bool {
        let content = getCurrentSummary()
        let tags = Self.extractSection(named: "Recent Journal Tags", from: content) ?? ""
        let checkups = Self.extractSection(named: "Recent Checkup Results", from: content) ?? ""
        return tags.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && checkups.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// The last-modified time of the file on disk — used by the greeting cache to
    /// decide whether a regeneration is needed.
    func lastModified() -> Date? {
        try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.modificationDate] as? Date
    }

    // MARK: - Persistence

    /// Writes content to disk and refreshes the in-memory cache.
    private func persist(_ content: String) {
        cachedContent = content
        try? content.data(using: .utf8)?.write(to: fileURL, options: .atomic)
    }

    // MARK: - Markdown Helpers (static, pure)

    /// Empty file scaffold matching the documented schema.
    private static func emptyScaffold() -> String {
        """
        # Health Summary
        **Last Updated:** \(isoTimestamp(Date()))
        **User Profile:** Age: — | Blood Type: —

        ## Active Conditions

        ## Lab Trends
        | Marker | Normal Range | Status |
        |--------|--------------|--------|

        ## Recent Journal Tags (last 30 entries max)

        ## Recent Checkup Results (last 20 max)

        ## Medications

        ## Doctor Notes & Follow-ups

        ## Flagged Abnormals

        ## Daily Summary Context
        **Last Generated:** \(isoTimestamp(Date()))
        No recent health context available yet.
        """
    }

    /// Returns the body text of a `## Section` (excluding the heading line), or nil.
    private static func extractSection(named name: String, from content: String) -> String? {
        let lines = content.components(separatedBy: "\n")
        guard let start = lines.firstIndex(where: { $0.hasPrefix("## ") && $0.contains(name) }) else { return nil }
        var body: [String] = []
        for line in lines[(start + 1)...] {
            if line.hasPrefix("## ") { break }
            body.append(line)
        }
        return body.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Appends `line` under the named section, capping the section's bullet lines at `cappedAt`
    /// (keeps the most recent). Returns the modified content.
    private static func appendToSection(named name: String, line: String, in content: String, cappedAt: Int) -> String {
        var lines = content.components(separatedBy: "\n")
        guard let start = lines.firstIndex(where: { $0.hasPrefix("## ") && $0.contains(name) }) else {
            // Section missing — append a new one at the end.
            return content + "\n\n## \(name)\n\(line)"
        }
        // Find the end of this section.
        var end = lines.count
        for i in (start + 1)..<lines.count where lines[i].hasPrefix("## ") {
            end = i
            break
        }
        // Existing bullet lines within the section.
        var bullets = lines[(start + 1)..<end].filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("-") }
        bullets.append(line)
        if bullets.count > cappedAt {
            bullets = Array(bullets.suffix(cappedAt))
        }
        // Rebuild: heading + bullets + a trailing blank line, replacing the old section body.
        let rebuilt = [lines[start]] + bullets + [""]
        lines.replaceSubrange(start..<end, with: rebuilt)
        return lines.joined(separator: "\n")
    }

    /// Replaces the entire body of the named section with `body`. Returns modified content.
    private static func replaceSectionBody(named name: String, with body: String, in content: String) -> String {
        var lines = content.components(separatedBy: "\n")
        guard let start = lines.firstIndex(where: { $0.hasPrefix("## ") && $0.contains(name) }) else {
            return content + "\n\n## \(name)\n\(body)"
        }
        var end = lines.count
        for i in (start + 1)..<lines.count where lines[i].hasPrefix("## ") {
            end = i
            break
        }
        let rebuilt = [lines[start]] + body.components(separatedBy: "\n") + [""]
        lines.replaceSubrange(start..<end, with: rebuilt)
        return lines.joined(separator: "\n")
    }

    /// Updates the `**Last Updated:**` line at the top of the file.
    private static func touchLastUpdated(_ content: String) -> String {
        var lines = content.components(separatedBy: "\n")
        if let idx = lines.firstIndex(where: { $0.hasPrefix("**Last Updated:**") }) {
            lines[idx] = "**Last Updated:** \(isoTimestamp(Date()))"
        }
        return lines.joined(separator: "\n")
    }

    private static func isoTimestamp(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    private static func isoDay(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    /// Pulls the first plain-text line out of a Markdown analysis string — strips
    /// `### ` headings and `• ` / `- ` bullet markers, skips blank lines, and caps
    /// the length so the curated file stays compact.
    private static func firstPlainSentence(from markdown: String, maxLength: Int = 220) -> String? {
        for raw in markdown.components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }
            let cleaned = (line.hasPrefix("• ") || line.hasPrefix("- "))
                ? String(line.dropFirst(2))
                : line
            let trimmed = cleaned.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            return String(trimmed.prefix(maxLength))
        }
        return nil
    }
}
