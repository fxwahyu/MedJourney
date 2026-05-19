//
//  AppTextField.swift
//  MedJourney
//
//  Components — Styled text input field
//

import SwiftUI

/// A styled text input field with label, placeholder, focus glow, and error state.
///
/// Matches the Figma spec: rounded corners (16pt), brand border on focus,
/// glow ring, and error styling.
///
/// Usage:
/// ```swift
/// @State private var name = ""
///
/// AppTextField(
///     "Full Name",
///     text: $name,
///     placeholder: "Enter your name",
///     icon: "person"
/// )
///
/// AppTextField(
///     "Email",
///     text: $email,
///     placeholder: "you@example.com",
///     errorMessage: viewModel.emailError
/// )
/// ```
struct AppTextField: View {

    // MARK: - Properties

    let label: String
    @Binding var text: String
    let placeholder: String
    let icon: String?
    let errorMessage: String?
    let keyboardType: UIKeyboardType
    let isSecure: Bool

    @FocusState private var isFocused: Bool

    // MARK: - Initialization

    init(
        _ label: String,
        text: Binding<String>,
        placeholder: String = "",
        icon: String? = nil,
        errorMessage: String? = nil,
        keyboardType: UIKeyboardType = .default,
        isSecure: Bool = false
    ) {
        self.label = label
        self._text = text
        self.placeholder = placeholder
        self.icon = icon
        self.errorMessage = errorMessage
        self.keyboardType = keyboardType
        self.isSecure = isSecure
    }

    // MARK: - Computed

    private var hasError: Bool { errorMessage != nil }

    private var borderColor: Color {
        if hasError { return AppColors.error }
        if isFocused { return AppColors.brand }
        return AppColors.border
    }

    private var borderWidth: CGFloat {
        (isFocused || hasError) ? 1.0 : 1.0
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // Label
            Text(label)
                .styled(.labelCaps)
                .foregroundStyle(hasError ? AppColors.error : AppColors.textTertiary)

            // Input field
            HStack(spacing: AppSpacing.sm) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundStyle(isFocused ? AppColors.brand : AppColors.textTertiary)
                }

                if isSecure {
                    SecureField(placeholder, text: $text)
                        .appFont(.body)
                        .focused($isFocused)
                } else {
                    TextField(placeholder, text: $text)
                        .appFont(.body)
                        .keyboardType(keyboardType)
                        .focused($isFocused)
                }
            }
            .padding(AppSpacing.lg)
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .stroke(borderColor, lineWidth: borderWidth)
            }
            .overlay {
                // Focus glow ring
                if isFocused && !hasError {
                    RoundedRectangle(cornerRadius: AppRadius.md)
                        .stroke(AppColors.brand.opacity(0.1), lineWidth: 4)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isFocused)

            // Error message
            if let errorMessage {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 12))
                    Text(errorMessage)
                        .appFont(.caption)
                }
                .foregroundStyle(AppColors.error)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: hasError)
    }
}

// MARK: - Preview

#Preview("Text Field States") {
    VStack(spacing: AppSpacing.xxl) {
        AppTextField(
            "Full Name",
            text: .constant(""),
            placeholder: "Enter your name",
            icon: "person"
        )

        AppTextField(
            "Email",
            text: .constant("john@"),
            placeholder: "you@example.com",
            icon: "envelope",
            errorMessage: "Please enter a valid email"
        )

        AppTextField(
            "Blood Pressure",
            text: .constant("120/80"),
            placeholder: "mmHg",
            keyboardType: .numbersAndPunctuation
        )
    }
    .padding(AppSpacing.xxl)
    .background(AppColors.background)
}
