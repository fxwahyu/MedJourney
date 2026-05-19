//
//  APIEndpoint.swift
//  MedJourney
//
//  Core Networking Layer — Protocol-based endpoint abstraction
//

import Foundation

/// Defines the contract for any API endpoint in the app.
///
/// Conforming types describe everything needed to build a `URLRequest`:
/// base URL, path, method, headers, query parameters, and body.
///
/// Usage:
/// ```swift
/// enum UserEndpoint: APIEndpoint {
///     case list
///     case detail(id: Int)
///
///     var baseURL: String { "https://api.example.com" }
///     var path: String {
///         switch self {
///         case .list: return "/users"
///         case .detail(let id): return "/users/\(id)"
///         }
///     }
///     var method: HTTPMethod { .get }
/// }
/// ```
protocol APIEndpoint {
    /// The base URL of the API (e.g., "https://api.example.com")
    var baseURL: String { get }

    /// The path component appended to the base URL (e.g., "/users")
    var path: String { get }

    /// The HTTP method for this request
    var method: HTTPMethod { get }

    /// HTTP headers to include in the request
    var headers: [String: String] { get }

    /// URL query parameters (e.g., `?page=1&limit=20`)
    var queryItems: [URLQueryItem]? { get }

    /// The HTTP body data (for POST, PUT, PATCH requests)
    var body: Data? { get }

    /// Timeout interval for this request in seconds
    var timeoutInterval: TimeInterval { get }
}

// MARK: - Default Implementations

extension APIEndpoint {

    var headers: [String: String] {
        [
            "Content-Type": "application/json",
            "Accept": "application/json"
        ]
    }

    var queryItems: [URLQueryItem]? { nil }

    var body: Data? { nil }

    var timeoutInterval: TimeInterval { 30.0 }

    /// Constructs a `URLRequest` from the endpoint's properties.
    ///
    /// - Throws: `NetworkError.invalidURL` if the URL cannot be constructed.
    /// - Returns: A fully configured `URLRequest`.
    func asURLRequest() throws -> URLRequest {
        guard var urlComponents = URLComponents(string: baseURL + path) else {
            throw NetworkError.invalidURL
        }

        urlComponents.queryItems = queryItems

        guard let url = urlComponents.url else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.timeoutInterval = timeoutInterval

        headers.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        request.httpBody = body

        return request
    }
}
