//
//  PostDetailView.swift
//  MedJourney
//
//  Feature: Posts — Detail screen for a single post
//

import SwiftUI

/// Displays the full content of a single post.
///
/// Demonstrates navigation destination and design system usage.
struct PostDetailView: View {

    let post: Post

    var body: some View {
        ZStack(alignment: .top) {
            AppColors.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    GradientHeader(height: 180) {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Spacer()
                            Text("Post #\(post.id)")
                                .styled(.labelCaps)
                                .foregroundStyle(.white.opacity(0.7))
                            Text(post.title.capitalized)
                                .appFont(.h2)
                                .foregroundStyle(.white)
                                .lineLimit(3)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, AppSpacing.xxl)
                    }

                    // Content
                    VStack(spacing: AppSpacing.lg) {
                        // Author card
                        AppCard(
                            showBorder: true,
                            borderColor: AppColors.brand.opacity(0.3)
                        ) {
                            HStack(spacing: AppSpacing.md) {
                                AvatarView(name: "User \(post.userId)")
                                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                    Text("User \(post.userId)")
                                        .appFont(.bodySemibold)
                                        .foregroundStyle(AppColors.textPrimary)
                                    Text("Author")
                                        .appFont(.caption)
                                        .foregroundStyle(AppColors.textTertiary)
                                }
                                Spacer()
                                BadgePill("Author", style: .brand, icon: "person")
                            }
                        }

                        // Body card
                        AppCard {
                            VStack(alignment: .leading, spacing: AppSpacing.md) {
                                Text("Content")
                                    .styled(.labelCaps)
                                    .foregroundStyle(AppColors.textTertiary)
                                Text(post.body)
                                    .appFont(.bodyLarge)
                                    .foregroundStyle(AppColors.textPrimary)
                                    .lineSpacing(6)
                            }
                        }
                    }
                    .padding(AppSpacing.lg)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        PostDetailView(post: Post(
            id: 1,
            userId: 1,
            title: "Sample post title for preview",
            body: "This is the body content of the post. It demonstrates how the detail view looks with actual content displayed in the app card."
        ))
    }
}
