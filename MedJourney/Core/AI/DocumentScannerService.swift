//
//  DocumentScannerService.swift
//  MedJourney
//

import UIKit
import Vision

enum DocumentScannerError: Error {
    case invalidImage
    case recognitionFailed(Error)
}

/// On-device OCR for uploaded medical documents, using Apple's Vision framework.
final class DocumentScannerService {

    /// Extracts recognized text from the images, concatenated in order.
    func extractText(from images: [UIImage]) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            // Vision is synchronous and CPU heavy — run off the calling thread.
            DispatchQueue.global(qos: .userInitiated).async {
                var fullText = ""

                for image in images {
                    guard let cgImage = image.cgImage else { continue }

                    let request = VNRecognizeTextRequest { request, error in
                        guard error == nil,
                              let observations = request.results as? [VNRecognizedTextObservation] else { return }
                        let strings = observations.compactMap { $0.topCandidates(1).first?.string }
                        fullText += strings.joined(separator: "\n") + "\n\n"
                    }
                    request.recognitionLevel = .accurate
                    request.usesLanguageCorrection = true

                    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                    try? handler.perform([request])
                }

                continuation.resume(returning: fullText.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
    }
}
