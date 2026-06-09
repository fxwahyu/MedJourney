//
//  CheckupOCRService.swift
//  MedJourney
//
//  Services/AI — Layer 1 (checkups): on-device OCR of uploaded documents.
//
//  Uses Apple's Vision framework (`VNRecognizeTextRequest`) to turn an uploaded
//  image or PDF into clean plain text. The text is then handed to the cloud LLM
//  exactly once (by CheckupUploadPipeline) for deep analysis.
//
//  NOTE: An existing `DocumentScannerService` already does Vision OCR on [UIImage].
//  This service is the data-oriented entry point for the new pipeline (accepts raw
//  Data / PDF Data) and does not replace the existing scanner.
//  TODO: integrate with existing DocumentScannerService if image-array OCR is needed.
//
//  UIKit/PDFKit are imported only because the Vision + PDF rasterization APIs require them.
//

import Foundation
import Vision
import UIKit
import PDFKit

/// Errors thrown during checkup OCR.
enum CheckupOCRError: Error {
    case invalidImageData
    case invalidPDFData
    case recognitionFailed(Error)
}

/// On-device OCR for uploaded checkup images and PDFs.
final class CheckupOCRService {

    static let shared = CheckupOCRService()

    init() {}

    /// Extracts recognized text from a single image's raw `Data`.
    /// - Returns: Clean, newline-joined plain text ready for the LLM.
    func extractText(from imageData: Data) async throws -> String {
        guard let image = UIImage(data: imageData), let cgImage = image.cgImage else {
            throw CheckupOCRError.invalidImageData
        }
        return try await recognizeText(in: cgImage)
    }

    /// Extracts recognized text from a PDF's raw `Data`, rasterizing and OCR-ing page by page.
    /// - Returns: Clean plain text with pages separated by blank lines.
    func extractText(fromPDF pdfData: Data) async throws -> String {
        guard let document = PDFDocument(data: pdfData) else {
            throw CheckupOCRError.invalidPDFData
        }

        var pages: [String] = []
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            let cgImage = try rasterize(page: page)
            let text = try await recognizeText(in: cgImage)
            if !text.isEmpty { pages.append(text) }
        }
        return pages.joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Vision

    /// Runs an accurate, language-corrected `VNRecognizeTextRequest` on a CGImage.
    /// All Vision objects are created inside the background closure so non-Sendable
    /// Vision types never cross a concurrency boundary (matches DocumentScannerService).
    private func recognizeText(in cgImage: CGImage) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            // Vision is synchronous + CPU heavy — run off the calling actor/thread.
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true

                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                do {
                    try handler.perform([request])
                    let observations = request.results ?? []
                    let text = observations
                        .compactMap { $0.topCandidates(1).first?.string }
                        .joined(separator: "\n")
                    continuation.resume(returning: text.trimmingCharacters(in: .whitespacesAndNewlines))
                } catch {
                    continuation.resume(throwing: CheckupOCRError.recognitionFailed(error))
                }
            }
        }
    }

    /// Rasterizes a single PDF page to a CGImage at 2× scale for legible OCR.
    private func rasterize(page: PDFPage) throws -> CGImage {
        let bounds = page.bounds(for: .mediaBox)
        let scale: CGFloat = 2.0
        let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)

        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            UIColor.white.set()
            ctx.fill(CGRect(origin: .zero, size: size))
            ctx.cgContext.translateBy(x: 0, y: size.height)
            ctx.cgContext.scaleBy(x: scale, y: -scale)
            page.draw(with: .mediaBox, to: ctx.cgContext)
        }
        guard let cgImage = image.cgImage else { throw CheckupOCRError.invalidPDFData }
        return cgImage
    }
}
