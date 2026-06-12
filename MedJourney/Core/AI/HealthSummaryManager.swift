//
//  HealthSummaryManager.swift
//  MedJourney
//

import Foundation

/// Owner of the curated `health_summary.md` context file — the heart of the
/// token-efficient AI pipeline. Raw journal entries and checkup documents are
/// never re-sent to the cloud; each save appends a compact line here, and only
/// this file (or a slice of it) is used as LLM context.
///
/// Implemented as an actor so all file I/O is serialized. The file is an
/// additional context layer — SwiftData remains the source of truth.
actor HealthSummaryManager {

    static let shared = HealthSummaryManager()

    private let maxJournalTagEntries = 30
    private let maxCheckupResults = 20

    private let fileURL: URL
    private var cachedContent: String?

    init(fileName: String = "health_summary.md") {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.fileURL = docs.appendingPathComponent(fileName)
    }

    // MARK: - Read

    /// Returns the full current markdown summary, creating an empty scaffold if none exists.
    func getCurrentSummary() -> String {
        if let cached = cachedContent { return cached }
        let content = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? Self.emptyScaffold()
        cachedContent = content
        return content
    }

    /// Returns the compact context slice for the daily greeting generator.
    ///
    /// Prefers the explicit "Daily Summary Context" section; when that hasn't been
    /// written yet (seed data, fresh install), synthesises a snapshot from whatever
    /// sections are populated so the LLM still gets something specific.
    func getDailySummaryContext() -> String {
        let content = getCurrentSummary()

        if let explicit = Self.extractSection(named: "Daily Summary Context", from: content),
           !explicit.isEmpty,
           !explicit.contains("No recent health context") {
            return explicit
        }

        var parts: [String] = []
        let sections: [(name: String, label: String)] = [
            ("Recent Journal Tags", "Recent journal observations"),
            ("Recent Checkup Results", "Recent checkup results"),
            ("Flagged Abnormals", "Flagged lab / vital results"),
            ("Doctor Notes & Follow-ups", "Doctor notes"),
            ("Medications", "Current medications"),
        ]
        for section in sections {
            if let body = Self.extractSection(named: section.name, from: content),
               !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                parts.append("\(section.label):\n\(body)")
            }
        }

        guard !parts.isEmpty else { return "No recent health context available yet." }
        return parts.joined(separator: "\n\n")
    }

    /// True when the file has no journal or checkup data yet. Used to decide whether
    /// to invalidate the greeting cache after a bootstrap.
    func isEffectivelyEmpty() -> Bool {
        let content = getCurrentSummary()
        let tags = Self.extractSection(named: "Recent Journal Tags", from: content) ?? ""
        let checkups = Self.extractSection(named: "Recent Checkup Results", from: content) ?? ""
        return tags.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && checkups.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Last-modified time of the file on disk — used by greeting caches to detect staleness.
    func lastModified() -> Date? {
        try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.modificationDate] as? Date
    }

    // MARK: - Write

    /// Populates the file from existing `JournalEntry` rows. Called at launch when
    /// entries were inserted directly into SwiftData (e.g. seed data) and bypassed
    /// the normal save pipeline. No-op once the file already has at least as many
    /// rows as SwiftData.
    func bootstrapFromEntries(_ entries: [JournalEntry]) {
        let content = getCurrentSummary()
        let journalEntries = entries.filter { $0.entryType == .journal }
        let checkupEntries = entries.filter { $0.entryType == .checkup }

        let needsJournal = Self.bulletCount(inSection: "Recent Journal Tags", of: content) < journalEntries.count
        let needsCheckups = Self.bulletCount(inSection: "Recent Checkup Results", of: content) < checkupEntries.count
        guard needsJournal || needsCheckups else { return }

        var updated = content

        if needsJournal {
            for entry in journalEntries.sorted(by: { $0.createdAt < $1.createdAt }) {
                let tagPart = entry.aiTags.isEmpty
                    ? (entry.title.isEmpty ? "(no tags)" : entry.title)
                    : entry.aiTags.joined(separator: ", ")
                let line = "- \(Self.isoDay(entry.createdAt)): \(tagPart)\(Self.vitalsSuffix(for: entry))"
                updated = Self.appendToSection(
                    named: "Recent Journal Tags (last 30 entries max)",
                    line: line, in: updated, cappedAt: maxJournalTagEntries
                )
            }
        }

        // Checkup lines include normal results too — an all-normal panel should let
        // the briefing say "your bloodwork looked healthy".
        if needsCheckups {
            for entry in checkupEntries.sorted(by: { $0.createdAt < $1.createdAt }) {
                let summary = entry.aiTags.isEmpty
                    ? "checkup logged"
                    : entry.aiTags.prefix(6).joined(separator: ", ")
                updated = Self.appendToSection(
                    named: "Recent Checkup Results (last 20 max)",
                    line: "- \(Self.isoDay(entry.createdAt)): \(summary)",
                    in: updated, cappedAt: maxCheckupResults
                )
            }
        }

        persist(Self.touchLastUpdated(updated))
    }

    /// Appends a compact journal line (tags + vitals) after a journal save.
    func updateFromJournalEntry(_ entry: JournalEntry, tags: [HealthTag]) {
        let tagLabels = tags.map(\.label)
        let tagPart = tagLabels.isEmpty ? entry.aiTags.joined(separator: ", ")
                                        : tagLabels.joined(separator: ", ")
        let line = "- \(Self.isoDay(entry.createdAt)): \(tagPart.isEmpty ? "(no tags)" : tagPart)\(Self.vitalsSuffix(for: entry))"

        var content = Self.appendToSection(
            named: "Recent Journal Tags (last 30 entries max)",
            line: line, in: getCurrentSummary(), cappedAt: maxJournalTagEntries
        )
        content = Self.touchLastUpdated(content)
        persist(content)
    }

    /// Records a checkup's AI results (tags + analysis excerpt) produced by the live
    /// checkup flow — no second analysis pass. Out-of-range-sounding tags are also
    /// reflected into "Flagged Abnormals". Raw OCR text is intentionally never stored.
    func updateFromExistingCheckupResult(tags: [String], analysisMarkdown: String?, date: Date) {
        var content = getCurrentSummary()
        let dateStr = Self.isoDay(date)

        let flagKeywords = ["below", "above", "elevated", "low ", "high ", "outside"]
        for tag in tags where flagKeywords.contains(where: { tag.lowercased().contains($0) }) {
            content = Self.appendToSection(
                named: "Flagged Abnormals",
                line: "- \(dateStr) \(tag) — from checkup",
                in: content, cappedAt: 50
            )
        }

        if !tags.isEmpty {
            let summary = tags.prefix(6).joined(separator: ", ")
            content = Self.appendToSection(
                named: "Recent Checkup Results (last 20 max)",
                line: "- \(dateStr): \(summary)",
                in: content, cappedAt: maxCheckupResults
            )
        }

        if let analysisMarkdown, let excerpt = Self.firstPlainSentence(from: analysisMarkdown) {
            content = Self.appendToSection(
                named: "Doctor Notes & Follow-ups",
                line: "- \(dateStr): \(excerpt)",
                in: content, cappedAt: 30
            )
        }

        persist(Self.touchLastUpdated(content))
    }

    /// Replaces the "Daily Summary Context" section with a freshly generated snapshot.
    func updateDailySummaryContext(_ snapshot: String) {
        let body = "**Last Generated:** \(Self.isoTimestamp(Date()))\n\(snapshot)"
        var content = Self.replaceSectionBody(named: "Daily Summary Context", with: body, in: getCurrentSummary())
        content = Self.touchLastUpdated(content)
        persist(content)
    }

    // MARK: - Persistence

    private func persist(_ content: String) {
        cachedContent = content
        try? content.data(using: .utf8)?.write(to: fileURL, options: .atomic)
    }

    // MARK: - Markdown Helpers

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

    private static func vitalsSuffix(for entry: JournalEntry) -> String {
        var vitals: [String] = []
        if let bp = entry.bloodPressure { vitals.append("BP \(bp)") }
        if let temp = entry.temperature { vitals.append("Temp \(temp)") }
        if let hr = entry.heartRate     { vitals.append("HR \(hr)") }
        return vitals.isEmpty ? "" : " | Vitals: \(vitals.joined(separator: ", "))"
    }

    private static func bulletCount(inSection name: String, of content: String) -> Int {
        let body = extractSection(named: name, from: content) ?? ""
        return body.components(separatedBy: "\n")
            .filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("-") }
            .count
    }

    /// Returns the body of a `## Section` (excluding the heading line), or nil.
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

    /// Appends `line` under the named section, keeping only the most recent
    /// `cappedAt` bullets. Creates the section at the end if missing.
    private static func appendToSection(named name: String, line: String, in content: String, cappedAt: Int) -> String {
        var lines = content.components(separatedBy: "\n")
        guard let start = lines.firstIndex(where: { $0.hasPrefix("## ") && $0.contains(name) }) else {
            return content + "\n\n## \(name)\n\(line)"
        }
        var end = lines.count
        for i in (start + 1)..<lines.count where lines[i].hasPrefix("## ") {
            end = i
            break
        }
        var bullets = lines[(start + 1)..<end].filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("-") }
        bullets.append(line)
        if bullets.count > cappedAt {
            bullets = Array(bullets.suffix(cappedAt))
        }
        lines.replaceSubrange(start..<end, with: [lines[start]] + bullets + [""])
        return lines.joined(separator: "\n")
    }

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
        lines.replaceSubrange(start..<end, with: [lines[start]] + body.components(separatedBy: "\n") + [""])
        return lines.joined(separator: "\n")
    }

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
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    /// First plain-text line of a markdown analysis — headings and bullet markers
    /// stripped, capped in length so the curated file stays compact.
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
