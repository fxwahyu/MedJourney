//
//  DocumentScannerService.swift
//  MedJourney
//
//  Core/Services — Extracts text from images and PDFs using Apple's Vision framework
//

import UIKit
import Vision

enum DocumentScannerError: Error {
    case invalidImage
    case recognitionFailed(Error)
}

/// A service to perform on-device OCR (Optical Character Recognition) on uploaded medical documents.
/// Uses Apple's native Vision framework to ensure data privacy and fast execution.
final class DocumentScannerService {
    
    /// Extracts text from an array of UIImages.
    /// - Parameter images: The images to scan.
    /// - Returns: A concatenated string of all recognized text.
    func extractText(from images: [UIImage]) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var fullText = ""
                
                for image in images {
                    guard let cgImage = image.cgImage else {
                        continue
                    }
                    
                    let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                    let request = VNRecognizeTextRequest { request, error in
                        if let error = error {
                            print("OCR Error: \(error.localizedDescription)")
                            return
                        }
                        
                        guard let observations = request.results as? [VNRecognizedTextObservation] else {
                            return
                        }
                        
                        let recognizedStrings = observations.compactMap { observation in
                            // Return the top candidate
                            observation.topCandidates(1).first?.string
                        }
                        
                        fullText += recognizedStrings.joined(separator: "\n")
                        fullText += "\n\n"
                    }
                    
                    // Optimize for accurate text recognition (vs fast)
                    request.recognitionLevel = .accurate
                    // Enable language correction
                    request.usesLanguageCorrection = true
                    
                    do {
                        try requestHandler.perform([request])
                    } catch {
                        print("Failed to perform OCR on image: \(error.localizedDescription)")
                    }
                }
                
                continuation.resume(returning: fullText.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
    }
}
