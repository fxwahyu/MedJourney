//
//  PostRepository.swift
//  MedJourney
//
//  Feature: Posts — Concrete repository using NetworkService
//

import Foundation

/// Concrete implementation of `PostRepositoryProtocol`.
///
/// Depends on `NetworkServiceProtocol` (injected), demonstrating
/// the Dependency Inversion principle — this class doesn't know
/// about `URLSession` or any networking details.
final class PostRepository: PostRepositoryProtocol {

    private let networkService: NetworkServiceProtocol

    init(networkService: NetworkServiceProtocol) {
        self.networkService = networkService
    }

    func fetchPosts() async throws -> [Post] {
        try await networkService.request(PostEndpoint.list)
    }

    func fetchPost(id: Int) async throws -> Post {
        try await networkService.request(PostEndpoint.detail(id: id))
    }
}
