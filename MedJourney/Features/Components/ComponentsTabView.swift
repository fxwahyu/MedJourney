//
//  ComponentsTabView.swift
//  MedJourney
//
//  Design System Showcase — All reusable components in one view
//

import SwiftUI

/// Showcases all reusable components from the design system.
///
/// Useful during development to visually verify component variants
/// without needing a live feature screen.
struct ComponentsTabView: View {

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.xxl) {
                    buttonsSection
                    badgesSection
                    cardsSection
                    glassmorphicSection
                    avatarsSection
                    colorsSection
                }
                .padding(AppSpacing.xxl)
            }
            .background(AppColors.background)
            .navigationTitle("Components")
        }
    }

    // MARK: - Buttons

    private var buttonsSection: some View {
        componentSection("Buttons") {
            VStack(spacing: AppSpacing.md) {
                AppButton("Primary", style: .primary, icon: "checkmark", isFullWidth: true) { }
                AppButton("Secondary", style: .secondary, icon: "stethoscope", isFullWidth: true) { }
                HStack(spacing: AppSpacing.md) {
                    AppButton("Ghost", style: .ghost) { }
                    AppButton("Destructive", style: .destructive, icon: "trash") { }
                }
                AppButton("Loading...", style: .primary, isFullWidth: true, isLoading: true) { }
            }
        }
    }

    // MARK: - Badges

    private var badgesSection: some View {
        componentSection("Badges") {
            HStack(spacing: AppSpacing.sm) {
                BadgePill("Symptom", style: .accent)
                BadgePill("Checkup", style: .violet)
                BadgePill("Brand", style: .brand, icon: "sparkles")
                BadgePill("Neutral", style: .neutral)
            }
        }
    }

    // MARK: - Cards

    private var cardsSection: some View {
        componentSection("Cards") {
            VStack(spacing: AppSpacing.md) {
                AppCard {
                    Text("Default card with subtle shadow")
                        .appFont(.body)
                        .foregroundStyle(AppColors.textSecondary)
                }
                AppCard(
                    shadowLevel: .elevated,
                    showBorder: true,
                    borderColor: AppColors.brand.opacity(0.3)
                ) {
                    Text("Elevated card with brand border")
                        .appFont(.body)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
    }

    // MARK: - Glassmorphic

    private var glassmorphicSection: some View {
        componentSection("Glassmorphic Card") {
            ZStack {
                AppGradients.header
                    .frame(height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl))
                GlassmorphicCard {
                    HStack {
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text("STREAK")
                                .styled(.labelCaps)
                                .foregroundStyle(.white.opacity(0.7))
                            Text("7 days")
                                .appFont(.h2)
                                .foregroundStyle(.white)
                        }
                        Spacer()
                        BadgePill("🔥 On fire", style: .accent)
                    }
                }
                .padding()
            }
        }
    }

    // MARK: - Avatars

    private var avatarsSection: some View {
        componentSection("Avatars") {
            HStack(spacing: AppSpacing.md) {
                AvatarView(name: "Ada Smith", size: .small)
                AvatarView(name: "Bob Jones", size: .medium)
                AvatarView(name: "Clara Day", size: .large)
            }
        }
    }

    // MARK: - Colors

    private var colorsSection: some View {
        componentSection("Color Palette") {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
            ], spacing: AppSpacing.sm) {
                colorSwatch("Brand", AppColors.brand)
                colorSwatch("Dark", AppColors.brandDark)
                colorSwatch("Deep", AppColors.brandDeeper)
                colorSwatch("Orange", AppColors.accentOrange)
                colorSwatch("Violet", AppColors.accentViolet)
                colorSwatch("Error", AppColors.error)
            }
        }
    }

    // MARK: - Helpers

    private func componentSection<C: View>(
        _ title: String,
        @ViewBuilder content: () -> C
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(title)
                .styled(.labelCaps)
                .foregroundStyle(AppColors.textTertiary)
            content()
        }
    }

    private func colorSwatch(_ name: String, _ color: Color) -> some View {
        VStack(spacing: AppSpacing.xs) {
            RoundedRectangle(cornerRadius: AppRadius.sm)
                .fill(color)
                .frame(height: 48)
            Text(name)
                .appFont(.caption)
                .foregroundStyle(AppColors.textSecondary)
        }
    }
}

#Preview {
    ComponentsTabView()
}
