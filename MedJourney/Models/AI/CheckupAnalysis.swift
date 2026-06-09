//
//  CheckupAnalysis.swift
//  MedJourney
//
//  Models/AI — Structured output of a deep checkup analysis (cloud LLM).
//
//  Produced by LLMAnalysisService.analyzeCheckup(extractedText:) and consumed by
//  CheckupUploadPipeline, which writes the *output only* into health_summary.md.
//

import Foundation

/// The full result of analysing one uploaded checkup document.
struct CheckupAnalysis: Codable {

    /// 2–3 sentence plain-language, non-diagnostic overview.
    let summary: String

    /// Markers the analysis flagged as outside their reference range.
    let flaggedMarkers: [LabMarker]

    /// General wellness recommendations (never medical treatment).
    let recommendations: [String]

    /// Suggested supportive daily habits for the checklist feature.
    ///
    /// Uses the existing `ChecklistGenerationItem` type so the result flows
    /// straight into the current checklist pipeline.
    /// TODO: integrate with existing ChecklistItem (SwiftData @Model) when persisting.
    let dailyChecklist: [ChecklistGenerationItem]

    /// The raw OCR text the analysis was derived from (kept for traceability;
    /// NOT re-sent to the LLM on later calls — that's the whole point of the MD layer).
    let rawExtractedText: String

    /// When the analysis was produced.
    let date: Date

    init(
        summary: String,
        flaggedMarkers: [LabMarker] = [],
        recommendations: [String] = [],
        dailyChecklist: [ChecklistGenerationItem] = [],
        rawExtractedText: String,
        date: Date = Date()
    ) {
        self.summary = summary
        self.flaggedMarkers = flaggedMarkers
        self.recommendations = recommendations
        self.dailyChecklist = dailyChecklist
        self.rawExtractedText = rawExtractedText
        self.date = date
    }
}
