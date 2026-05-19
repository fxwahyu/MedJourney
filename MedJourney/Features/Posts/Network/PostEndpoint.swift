//
//  PostEndpoint.swift
//  MedJourney
//
//  Feature: Posts — API endpoint definitions
//

import Foundation

/// API endpoints for the JSONPlaceholder posts resource.
///
/// Demonstrates how to define feature-specific endpoints
/// conforming to the `APIEndpoint` protocol.
enum PostEndpoint: APIEndpoint {
    /// Fetch all posts
    case list

    /// Fetch a single post by ID
    case detail(id: Int)

    /// Create a new post
    case create(title: String, body: String, userId: Int)

    // MARK: - APIEndpoint

    var baseURL: String {
        "https://jsonplaceholder.typicode.com"
    }

    var path: String {
        switch self {
        case .list:
            return "/posts"
        case .detail(let id):
            return "/posts/\(id)"
        case .create:
            return "/posts"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .list, .detail:
            return .get
        case .create:
            return .post
        }
    }

    var body: Data? {
        switch self {
        case .list, .detail:
            return nil
        case .create(let title, let body, let userId):
            let payload: [String: Any] = [
                "title": title,
                "body": body,
                "userId": userId
            ]
            return try? JSONSerialization.data(withJSONObject: payload)
        }
    }
}
