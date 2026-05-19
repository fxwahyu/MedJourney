//
//  PostListView.swift
//  MedJourney
//
//  Feature: Posts — List screen demonstrating full stack integration
//

import SwiftUI

/// Displays a list of posts fetched from the JSONPlaceholder API.
///
/// Demonstrates full integration of all architecture layers:
/// - **Networking**: Data fetched via `PostRepository` → `NetworkService`
/// - **MVVM**: View observes `PostListViewModel`
/// - **Components**: Uses `AppCard`, `BadgePill`, `GradientHeader`, `LoadingStateView`
/// - **Design System**: Uses `AppColors`, `AppFont`, `AppSpacing`, `AppShadow`
struct PostListView: View {

    @State private var viewModel: PostListViewModel
    @State private var searchText = ""

    init(viewModel: PostListViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                AppColors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        headerSection
                        contentSection
                    }
                }
                .refreshable {
                    await viewModel.refresh()
                }
            }
            .navigationBarHidden(true)
            .task {
                if viewModel.viewState == .idle {
                    await viewModel.fetchPosts()
                }
            }
            .searchable(text: $searchText, prompt: "Search posts...")
            .onChange(of: searchText) { _, newValue in
                viewModel.updateSearch(newValue)
            }
            .ignoresSafeArea()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        GradientHeader(height: 200) {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Spacer()
                HStack {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("API Demo ✦")
                            .styled(.labelCaps)
                            .foregroundStyle(.white.opacity(0.7))
                        Text("Posts")
                            .appFont(.h1)
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    AvatarView(
                        name: "Demo User",
                        size: .medium,
                        backgroundColor: .white.opacity(0.25)
                    )
                }
                Text("\(viewModel.posts.count) posts loaded")
                    .appFont(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.bottom, AppSpacing.xxl)
        }
    }

    // MARK: - Content

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            switch viewModel.viewState {
            case .idle, .loading:
                LoadingStateView(state: .loading())
                    .frame(minHeight: 300)

            case .error(let message):
                LoadingStateView(state: .error(
                    message: message,
                    retryAction: {
                        Task { await viewModel.fetchPosts() }
                    }
                ))
                .frame(minHeight: 300)

            case .loaded:
                if viewModel.filteredPosts.isEmpty {
                    LoadingStateView(state: .empty(
                        title: "No posts found",
                        message: "Try a different search term.",
                        icon: "magnifyingglass"
                    ))
                    .frame(minHeight: 300)
                } else {
                    postsSection
                }
            }
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.top, AppSpacing.lg)
    }

    // MARK: - Posts List

    private var postsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Recent Posts")
                .styled(.labelCaps)
                .foregroundStyle(AppColors.textTertiary)
                .padding(.horizontal, AppSpacing.xs)

            LazyVStack(spacing: AppSpacing.md) {
                ForEach(viewModel.filteredPosts) { post in
                    NavigationLink(value: post) {
                        postCard(post)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationDestination(for: Post.self) { post in
            PostDetailView(post: post)
        }
    }

    // MARK: - Post Card

    private func postCard(_ post: Post) -> some View {
        AppCard(
            showBorder: false,
            borderColor: AppColors.border
        ) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack {
                    BadgePill("User \(post.userId)", style: .brand, icon: "person")
                    Spacer()
                    Text("#\(post.id)")
                        .appFont(.caption)
                        .foregroundStyle(AppColors.textTertiary)
                }

                Text(post.title.capitalized)
                    .appFont(.bodySemibold)
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(2)

                Text(post.body)
                    .appFont(.caption)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(2)

                HStack {
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppColors.textTertiary)
                }
            }
        }
    }
}

#Preview {
    PostListView(
        viewModel: PostListViewModel(
            repository: PostRepository(
                networkService: NetworkService()
            )
        )
    )
}
