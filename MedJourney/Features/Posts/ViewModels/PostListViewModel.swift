//
//  PostListViewModel.swift
//  MedJourney
//
//  Feature: Posts — ViewModel with loading state management
//

import Foundation

/// ViewModel for the posts list screen.
///
/// Demonstrates MVVM with:
/// - `@Observable` for SwiftUI reactivity
/// - Protocol-based dependency (`PostRepositoryProtocol`)
/// - Typed loading state enum
/// - Async data fetching with error handling
@Observable
final class PostListViewModel {

    // MARK: - Loading State

    /// Represents the current state of the data fetch.
    enum ViewState: Equatable {
        case idle
        case loading
        case loaded
        case error(String)
    }

    // MARK: - Published State

    private(set) var posts: [Post] = []
    private(set) var viewState: ViewState = .idle
    private(set) var searchText: String = ""

    // MARK: - Dependencies

    private let repository: PostRepositoryProtocol

    // MARK: - Computed

    /// Posts filtered by search text.
    var filteredPosts: [Post] {
        guard !searchText.isEmpty else { return posts }
        return posts.filter { post in
            post.title.localizedCaseInsensitiveContains(searchText)
            || post.body.localizedCaseInsensitiveContains(searchText)
        }
    }

    // MARK: - Initialization

    /// Creates a ViewModel with an injected repository.
    ///
    /// - Parameter repository: The data source for posts.
    ///   Defaults to a live `PostRepository` with `NetworkService`.
    init(repository: PostRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Actions

    /// Fetches posts from the repository.
    @MainActor
    func fetchPosts() async {
        guard viewState != .loading else { return }
        viewState = .loading

        do {
            posts = try await repository.fetchPosts()
            viewState = .loaded
        } catch let error as NetworkError {
            viewState = .error(error.errorDescription ?? "Unknown error")
        } catch {
            viewState = .error(error.localizedDescription)
        }
    }

    /// Refreshes the posts list (for pull-to-refresh).
    @MainActor
    func refresh() async {
        do {
            posts = try await repository.fetchPosts()
            viewState = .loaded
        } catch let error as NetworkError {
            viewState = .error(error.errorDescription ?? "Unknown error")
        } catch {
            viewState = .error(error.localizedDescription)
        }
    }

    /// Updates the search filter text.
    func updateSearch(_ text: String) {
        searchText = text
    }
}
