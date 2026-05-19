//
//  AppTextArea.swift
//  MedJourney
//
//  Components — Multi-line text editor with styled border
//

import SwiftUI

/// A styled multi-line text input matching the Figma spec.
///
/// Features a rounded border (20pt), focus glow effect,
/// character count, and serif-italic placeholder styling.
///
/// Usage:
/// ```swift
/// @State private var notes = ""
///
/// AppTextArea(
///     "What's on your mind?",
///     text: $notes,
///     placeholder: "Describe what you're experiencing..."
/// )
/// ```
struct AppTextArea: View {

    // MARK: - Properties

    let label: String
    @Binding var text: String
    let placeholder: String
    let minHeight: CGFloat
    let maxCharacters: Int?

    @FocusState private var isFocused: Bool

    // MARK: - Initialization

    init(
        _ label: String,
        text: Binding<String>,
        placeholder: String = "",
        minHeight: CGFloat = 120,
        maxCharacters: Int? = nil
    ) {
        self.label = label
        self._text = text
        self.placeholder = placeholder
        self.minHeight = minHeight
        self.maxCharacters = maxCharacters
    }

    // MARK: - Computed

    private var borderColor: Color {
        isFocused ? AppColors.brand : AppColors.border
    }

    private var borderWidth: CGFloat {
        isFocused ? 1.0 : 1.0
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // Label
            Text(label)
                .styled(.labelCaps)
                .foregroundStyle(AppColors.textTertiary)

            // Text editor with placeholder
            ZStack(alignment: .topLeading) {
                // Placeholder
                if text.isEmpty {
                    Text(placeholder)
                        .font(.system(size: 14, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(AppColors.textTertiary)
                        .padding(.top, AppSpacing.lg)
                        .padding(.horizontal, AppSpacing.lg)
                }

                // Editor
                TextEditor(text: $text)
                    .appFont(.body)
                    .foregroundStyle(AppColors.textPrimary)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
                    .focused($isFocused)
                    .frame(minHeight: minHeight)
                    .onChange(of: text) { _, newValue in
                        if let maxCharacters, newValue.count > maxCharacters {
                            text = String(newValue.prefix(maxCharacters))
                        }
                    }
            }
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .stroke(borderColor, lineWidth: borderWidth)
            }
            .overlay {
                if isFocused {
                    RoundedRectangle(cornerRadius: AppRadius.lg)
                        .stroke(AppColors.brand.opacity(0.1), lineWidth: 4)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isFocused)

            // Character count
            if let maxCharacters {
                HStack {
                    Spacer()
                    Text("\(text.count)/\(maxCharacters)")
                        .appFont(.caption)
                        .foregroundStyle(
                            text.count > maxCharacters - 20
                                ? AppColors.accentOrange
                                : AppColors.textTertiary
                        )
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Text Area") {
    VStack(spacing: AppSpacing.xxl) {
        AppTextArea(
            "What's on your mind?",
            text: .constant(""),
            placeholder: "Describe what you're experiencing — any symptoms, how long it's been going on, what makes it better or worse...",
            maxCharacters: 500
        )

        AppTextArea(
            "Doctor's Notes",
            text: .constant("Patient reports mild headache for the past 3 days."),
            placeholder: "Enter notes...",
            minHeight: 80
        )
    }
    .padding(AppSpacing.xxl)
    .background(AppColors.background)
}
