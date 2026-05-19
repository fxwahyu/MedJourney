//
//  AppButton.swift
//  MedJourney
//
//  Components — Reusable button with multiple variants
//

import SwiftUI

/// A reusable, styled button component with multiple visual variants.
///
/// Supports primary, secondary, ghost, and destructive styles with
/// optional icons, loading states, and full-width layout.
///
/// Usage:
/// ```swift
/// AppButton("Save Entry", style: .primary, icon: "checkmark") {
///     viewModel.save()
/// }
///
/// AppButton("Cancel", style: .ghost) {
///     dismiss()
/// }
///
/// AppButton("Save", style: .primary, isLoading: true) { }
/// ```
struct AppButton: View {

    // MARK: - Style

    /// Visual style variants for the button.
    enum Style {
        /// Brand-colored filled button — primary actions
        case primary

        /// Outlined button with brand border — secondary actions
        case secondary

        /// Text-only button with no background — tertiary actions
        case ghost

        /// Red-filled button — destructive/dangerous actions
        case destructive
    }

    /// Size variants for the button.
    enum Size {
        case small
        case medium
        case large

        var verticalPadding: CGFloat {
            switch self {
            case .small: return AppSpacing.sm
            case .medium: return AppSpacing.md
            case .large: return AppSpacing.lg
            }
        }

        var horizontalPadding: CGFloat {
            switch self {
            case .small: return AppSpacing.lg
            case .medium: return AppSpacing.xl
            case .large: return AppSpacing.xxl
            }
        }

        var fontStyle: AppFont {
            switch self {
            case .small: return .bodySemibold
            case .medium, .large: return .button
            }
        }
    }

    // MARK: - Properties

    let title: String
    let style: Style
    let size: Size
    let icon: String?
    let isFullWidth: Bool
    let isLoading: Bool
    let isDisabled: Bool
    let action: () -> Void

    // MARK: - Initialization

    /// Creates a new `AppButton`.
    ///
    /// - Parameters:
    ///   - title: The button label text.
    ///   - style: Visual style variant. Defaults to `.primary`.
    ///   - size: Size variant. Defaults to `.medium`.
    ///   - icon: Optional SF Symbol name for a leading icon.
    ///   - isFullWidth: Whether the button stretches to full width. Defaults to `false`.
    ///   - isLoading: Shows a loading spinner and disables interaction. Defaults to `false`.
    ///   - isDisabled: Disables the button. Defaults to `false`.
    ///   - action: The closure to execute when tapped.
    init(
        _ title: String,
        style: Style = .primary,
        size: Size = .medium,
        icon: String? = nil,
        isFullWidth: Bool = false,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.style = style
        self.size = size
        self.icon = icon
        self.isFullWidth = isFullWidth
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.action = action
    }

    // MARK: - Body

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.sm) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(foregroundColor)
                        .scaleEffect(0.8)
                } else {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 14, weight: .semibold))
                    }
                }

                Text(title)
                    .appFont(size.fontStyle)
            }
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .padding(.vertical, size.verticalPadding)
            .padding(.horizontal, size.horizontalPadding)
            .foregroundStyle(foregroundColor)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
            .overlay {
                if style == .secondary {
                    RoundedRectangle(cornerRadius: AppRadius.md)
                        .stroke(AppColors.brandDark, lineWidth: 1.5)
                }
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(isDisabled || isLoading)
        .opacity(isDisabled ? 0.5 : 1.0)
    }

    // MARK: - Computed Colors

    private var foregroundColor: Color {
        switch style {
        case .primary: return .white
        case .secondary: return AppColors.brandDark
        case .ghost: return AppColors.brandDark
        case .destructive: return .white
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .primary: return AppColors.brand
        case .secondary: return AppColors.surface
        case .ghost: return .clear
        case .destructive: return AppColors.error
        }
    }
}

// MARK: - Scale Button Style

/// Press animation that scales the button down slightly on tap.
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview("Button Variants") {
    VStack(spacing: AppSpacing.lg) {
        AppButton("Primary Button", style: .primary, icon: "checkmark", isFullWidth: true) { }
        AppButton("Secondary Button", style: .secondary, icon: "stethoscope", isFullWidth: true) { }
        AppButton("Ghost Button", style: .ghost) { }
        AppButton("Destructive", style: .destructive, icon: "trash") { }
        AppButton("Loading...", style: .primary, isFullWidth: true, isLoading: true) { }
        AppButton("Disabled", style: .primary, isFullWidth: true, isDisabled: true) { }
    }
    .padding(AppSpacing.xxl)
    .background(AppColors.background)
}
