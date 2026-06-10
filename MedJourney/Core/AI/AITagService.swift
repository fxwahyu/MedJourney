//
//  AITagService.swift
//  MedJourney
//
//  Core/AI — Shared contracts for AI tag generation.
//
//  This file holds ONLY the shared types used across the tagging feature:
//  the result struct, the service protocol, and the error enum. The concrete
//  tag generator is `LLMTagService`, and every provider call it makes is
//  routed through the single `LLMGateway` (see LLMGateway.swift). There is no
//  per-provider tag service in app code — to change provider, edit the gateway.
//

import Foundation

// MARK: - Models

/// The result from the AI analysis containing tags and detailed markdown analysis
struct AITagResult {
    let tags: [String]
    let analysis: String?
}

// MARK: - Protocol

/// Generates AI-powered health tags from a journal entry's content.
/// Implemented by `LLMTagService`, which routes all calls through `LLMGateway`.
protocol AITagServiceProtocol {
    func generateTags(for entry: JournalEntry, ocrText: String?) async throws -> AITagResult
}

// MARK: - Errors

enum AITagError: LocalizedError {
    case missingAPIKey
    case apiError(Int)
    case parseError

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:      return "No API key configured (Config.plist / environment variable)."
        case .apiError(let code): return "AI tag service error: HTTP \(code)"
        case .parseError:         return "Failed to parse AI service response"
        }
    }
}
