//
//  CheckupUploadPipeline.swift
//  MedJourney
//
//  Services/AI — Orchestrates everything that happens when a checkup is uploaded.
//
//  Flow:
//   1. CheckupOCRService → extract text on-device (image or PDF).
//   2. LLMAnalysisService.analyzeCheckup → ONE deep cloud analysis of the OCR text.
//   3. HealthSummaryManager → write the analysis *output* into health_summary.md
//      (flagged values, doctor notes) + refresh the Daily Summary Context section.
//   4. Return the full CheckupAnalysis to the UI layer.
//
//  TODO: integrate with existing CheckupViewModel / JournalEntry(.checkup) — this
//  pipeline produces the analysis; the existing layer owns persistence of the entry.
//

import Foundation

/// The type of file a user uploaded for a checkup.
enum CheckupFileType {
    case image   // JPEG/PNG/HEIC raw data
    case pdf     // PDF document data
}

/// Coordinates OCR → cloud analysis → MD-file update for an uploaded checkup.
final class CheckupUploadPipeline {

    static let shared = CheckupUploadPipeline()

    private let ocr: CheckupOCRService
    private let llm: LLMAnalysisService
    private let summaryManager: HealthSummaryManager

    init(
        ocr: CheckupOCRService = .shared,
        llm: LLMAnalysisService = .shared,
        summaryManager: HealthSummaryManager = .shared
    ) {
        self.ocr = ocr
        self.llm = llm
        self.summaryManager = summaryManager
    }

    /// Runs the full checkup-upload pipeline and returns the deep analysis.
    /// - Parameters:
    ///   - fileData: Raw uploaded bytes (image or PDF).
    ///   - fileType: Whether `fileData` is an image or a PDF.
    func process(fileData: Data, fileType: CheckupFileType) async throws -> CheckupAnalysis {
        // Step 1 — on-device OCR (free, private).
        let extractedText: String
        switch fileType {
        case .image: extractedText = try await ocr.extractText(from: fileData)
        case .pdf:   extractedText = try await ocr.extractText(fromPDF: fileData)
        }

        // Step 2 — single cloud LLM deep analysis of the extracted text.
        let analysis = try await llm.analyzeCheckup(extractedText: extractedText)

        // Step 3 — persist only the analysis OUTPUT into the curated MD file,
        // then refresh the small Daily Summary Context slice.
        await summaryManager.updateFromCheckupAnalysis(analysis)
        await summaryManager.updateDailySummaryContext(Self.buildSnapshot(from: analysis))

        // Step 4 — hand the full analysis back to the UI layer.
        return analysis
    }

    /// Builds a compact snapshot for the Daily Summary Context from the analysis.
    private static func buildSnapshot(from analysis: CheckupAnalysis) -> String {
        let flagged = analysis.flaggedMarkers.filter(\.isAbnormal).map(\.name)
        if flagged.isEmpty {
            return "Recent checkup reviewed — results were largely within typical ranges."
        }
        return "Recent checkup flagged \(flagged.joined(separator: ", ")) for follow-up. \(analysis.summary)"
    }
}
