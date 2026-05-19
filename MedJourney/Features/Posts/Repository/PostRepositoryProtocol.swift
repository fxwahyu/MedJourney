//
//  PostRepositoryProtocol.swift
//  MedJourney
//
//  Feature: Posts — Repository abstraction
//

import Foundation

/// Defines the contract for fetching posts data.
///
/// ViewModels depend on this protocol, not the concrete repository.
/// This enables easy mocking for tests and swapping implementations.
protocol PostRepositoryProtocol {
    /// Fetches all posts from the remote API.
    func fetchPosts() async throws -> [Post]

    /// Fetches a single post by its ID.
    func fetchPost(id: Int) async throws -> Post
}
