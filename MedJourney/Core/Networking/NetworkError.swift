//
//  NetworkError.swift
//  MedJourney
//
//  Core Networking Layer — Typed error definitions
//

import Foundation

/// Represents all possible networking errors in the app.
///
/// Each case provides a user-friendly `errorDescription` via `LocalizedError`
/// conformance, making it easy to display in UI without additional mapping.
enum NetworkError: LocalizedError, Equatable {
    /// The URL could not be constructed from the endpoint
    case invalidURL

    /// The network request failed (e.g., timeout, DNS failure)
    case requestFailed(String)

    /// The server returned a non-HTTP response
    case invalidResponse

    /// JSON decoding failed
    case decodingFailed(String)

    /// Server returned an error status code (4xx, 5xx)
    case serverError(statusCode: Int)

    /// No internet connection available
    case noConnection

    /// Authentication required or token expired (401)
    case unauthorized

    /// An unknown or unexpected error occurred
    case unknown(String)

    // MARK: - LocalizedError

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The request URL is invalid."
        case .requestFailed(let message):
            return "Request failed: \(message)"
        case .invalidResponse:
            return "The server returned an invalid response."
        case .decodingFailed(let message):
            return "Failed to process server data: \(message)"
        case .serverError(let statusCode):
            return "Server error (code: \(statusCode)). Please try again later."
        case .noConnection:
            return "No internet connection. Please check your network settings."
        case .unauthorized:
            return "Your session has expired. Please log in again."
        case .unknown(let message):
            return "An unexpected error occurred: \(message)"
        }
    }
}
