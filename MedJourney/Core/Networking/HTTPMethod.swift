//
//  HTTPMethod.swift
//  MedJourney
//
//  Core Networking Layer — HTTP method definitions
//

import Foundation

/// Represents standard HTTP methods used in API requests.
///
/// Usage:
/// ```swift
/// let method: HTTPMethod = .get
/// request.httpMethod = method.rawValue // "GET"
/// ```
enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}
