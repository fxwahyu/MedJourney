//
//  AppTypography.swift
//  MedJourney
//
//  Design System — Typography scale and font definitions
//

import SwiftUI

/// Defines the typographic scale for the app.
///
/// The Figma spec uses:
/// - **Fraunces** (serif) for display/headings — warm, elegant
/// - **Plus Jakarta Sans** for body/UI — clean, modern
///
/// This implementation uses system font with `.serif` and `.rounded` designs
/// as stand-ins. To use custom fonts later, update the `font` computed property
/// in each case — all call sites remain unchanged.
///
/// Usage:
/// ```swift
/// Text("Hello")
///     .appFont(.h1)
///
/// Text("Subtitle")
///     .appFont(.body)
/// ```
enum AppFont {

    // MARK: - Heading Styles (Serif — Fraunces stand-in)

    /// H1: Large display heading — 28pt serif
    case h1

    /// H2: Section heading — 22pt serif
    case h2

    /// H3: Card/subsection heading — 18pt serif
    case h3

    // MARK: - UI Styles (Sans-serif — Plus Jakarta Sans stand-in)

    /// Label caps: 11pt, semibold, uppercase with letter spacing
    case labelCaps

    /// Body: Primary readable text — 14pt regular
    case body

    /// Body semibold: Emphasized body text — 14pt semibold
    case bodySemibold

    /// Caption: Secondary small text — 12pt regular
    case caption

    /// Small: Very small text — 11pt regular
    case small

    /// Button text — 15pt semibold
    case button

    /// Large body — 16pt regular
    case bodyLarge

    // MARK: - Font Properties

    /// The `Font` value for this typography style.
    var font: Font {
        switch self {
        case .h1:
            return .system(size: 28, weight: .regular, design: .serif)
        case .h2:
            return .system(size: 22, weight: .regular, design: .serif)
        case .h3:
            return .system(size: 18, weight: .medium, design: .serif)
        case .labelCaps:
            return .system(size: 11, weight: .semibold, design: .default)
        case .body:
            return .system(size: 14, weight: .regular, design: .default)
        case .bodySemibold:
            return .system(size: 14, weight: .semibold, design: .default)
        case .caption:
            return .system(size: 12, weight: .regular, design: .default)
        case .small:
            return .system(size: 11, weight: .regular, design: .default)
        case .button:
            return .system(size: 15, weight: .semibold, design: .default)
        case .bodyLarge:
            return .system(size: 16, weight: .regular, design: .default)
        }
    }

    /// The line spacing multiplier for this style.
    var lineSpacing: CGFloat {
        switch self {
        case .h1: return 4
        case .h2: return 3
        case .h3: return 2
        case .body, .bodySemibold, .bodyLarge: return 5
        case .caption, .small: return 3
        case .labelCaps: return 1
        case .button: return 0
        }
    }

    /// Whether this style should be uppercased.
    var isUppercased: Bool {
        switch self {
        case .labelCaps: return true
        default: return false
        }
    }

    /// The letter spacing (tracking) for this style.
    var tracking: CGFloat {
        switch self {
        case .labelCaps: return 0.9
        default: return 0
        }
    }
}

// MARK: - View Modifier

/// Applies a typography style from `AppFont` to a view.
struct AppFontModifier: ViewModifier {
    let style: AppFont

    func body(content: Content) -> some View {
        content
            .font(style.font)
            .lineSpacing(style.lineSpacing)
            .tracking(style.tracking)
    }
}

// MARK: - View Extension

extension View {

    /// Applies an `AppFont` typography style to the view.
    ///
    /// - Parameter style: The typography style to apply.
    /// - Returns: The view with the font, line spacing, and tracking applied.
    func appFont(_ style: AppFont) -> some View {
        modifier(AppFontModifier(style: style))
    }
}

// MARK: - Text Extension

extension Text {

    /// Applies an `AppFont` style to a `Text` view, including uppercase transform.
    ///
    /// Use this instead of `appFont()` when you need the uppercase transform
    /// for `.labelCaps` style.
    func styled(_ style: AppFont) -> some View {
        let baseText = style.isUppercased ? self.textCase(.uppercase) : self.textCase(nil)
        return baseText
            .font(style.font)
            .lineSpacing(style.lineSpacing)
            .tracking(style.tracking)
    }
}

