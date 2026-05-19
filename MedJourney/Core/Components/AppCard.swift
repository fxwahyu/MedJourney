//
//  AppCard.swift
//  MedJourney
//
//  Components — Reusable card container with shadow and optional press animation
//

import SwiftUI

/// A reusable card component with rounded corners, shadow, and optional border.
///
/// Wraps any content in a styled container matching the Figma card design.
/// Supports tappable mode with press-scale animation.
///
/// Usage:
/// ```swift
/// // Static card
/// AppCard {
///     Text("Card content")
/// }
///
/// // Tappable card with action
/// AppCard(shadowLevel: .elevated, onTap: { navigateToDetail() }) {
///     HStack {
///         Text("Tap me")
///         Spacer()
///         Image(systemName: "chevron.right")
///     }
/// }
///
/// // Card with border
/// AppCard(showBorder: true, borderColor: AppColors.brand) {
///     Text("Bordered card")
/// }
/// ```
struct AppCard<Content: View>: View {

    // MARK: - Properties

    let cornerRadius: CGFloat
    let shadowLevel: AppShadowLevel
    let backgroundColor: Color
    let showBorder: Bool
    let borderColor: Color
    let borderWidth: CGFloat
    let padding: CGFloat
    let onTap: (() -> Void)?
    let content: Content

    // MARK: - Initialization

    /// Creates a new `AppCard`.
    ///
    /// - Parameters:
    ///   - cornerRadius: Corner radius. Defaults to `AppRadius.xl` (24pt).
    ///   - shadowLevel: Shadow intensity. Defaults to `.card`.
    ///   - backgroundColor: Card background. Defaults to `AppColors.surface`.
    ///   - showBorder: Whether to show a border. Defaults to `false`.
    ///   - borderColor: Border color when `showBorder` is true. Defaults to `AppColors.border`.
    ///   - borderWidth: Border width. Defaults to `1`.
    ///   - padding: Internal padding. Defaults to `AppSpacing.xl` (20pt).
    ///   - onTap: Optional tap handler. Enables press animation when provided.
    ///   - content: The card's content, provided via `@ViewBuilder`.
    init(
        cornerRadius: CGFloat = AppRadius.xl,
        shadowLevel: AppShadowLevel = .card,
        backgroundColor: Color = AppColors.surface,
        showBorder: Bool = false,
        borderColor: Color = AppColors.border,
        borderWidth: CGFloat = 1,
        padding: CGFloat = AppSpacing.xl,
        onTap: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.shadowLevel = shadowLevel
        self.backgroundColor = backgroundColor
        self.showBorder = showBorder
        self.borderColor = borderColor
        self.borderWidth = borderWidth
        self.padding = padding
        self.onTap = onTap
        self.content = content()
    }

    // MARK: - Body

    var body: some View {
        Group {
            if let onTap {
                Button(action: onTap) {
                    cardContent
                }
                .buttonStyle(CardPressStyle())
            } else {
                cardContent
            }
        }
    }

    private var cardContent: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay {
                if showBorder {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(borderColor, lineWidth: borderWidth)
                }
            }
            .appShadow(shadowLevel)
    }
}

// MARK: - Card Press Style

/// Press animation for tappable cards — scales to 0.98 on press.
struct CardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview("Card Variants") {
    ScrollView {
        VStack(spacing: AppSpacing.lg) {
            AppCard {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("Default Card")
                        .appFont(.h3)
                        .foregroundStyle(AppColors.textPrimary)
                    Text("This is a basic card with default shadow.")
                        .appFont(.body)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }

            AppCard(
                shadowLevel: .elevated,
                showBorder: true,
                borderColor: AppColors.brand.opacity(0.3)
            ) {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("Elevated + Border")
                        .appFont(.h3)
                        .foregroundStyle(AppColors.textPrimary)
                    Text("Elevated shadow with brand border.")
                        .appFont(.body)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }

            AppCard(onTap: { }) {
                HStack {
                    Text("Tappable Card")
                        .appFont(.bodySemibold)
                        .foregroundStyle(AppColors.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(AppColors.textTertiary)
                }
            }
        }
        .padding(AppSpacing.xxl)
    }
    .background(AppColors.background)
}
