//
//  AppTypography.swift
//  MedJourney
//
//  Design System — Typography scale (Vital Calm)
//
//  Typefaces:
//  - Display/headings: Fraunces (warm editorial serif) — add Fraunces-*.ttf to target
//  - UI/body:          Plus Jakarta Sans — add PlusJakartaSans-*.ttf to target
//  - Numerals:         DM Mono — add DMMono-*.ttf to target; used for all clinical values
//
//  Until font files are bundled, each Font.custom call silently falls back to the system font.
//  Register fonts in Info.plist under UIAppFonts once added.
//

import SwiftUI

/// Typographic scale for the app.
enum AppFont {

    // MARK: - Heading Styles (Fraunces — editorial serif)

    /// H1: Large display heading — 33pt serif, sentence case
    case h1

    /// H2: Section heading — 22pt serif
    case h2

    /// H3: Card/subsection heading — 17pt serif
    case h3

    // MARK: - UI Styles (Plus Jakarta Sans)

    /// Label caps: 11pt, bold, uppercase with tracking
    case labelCaps

    /// Body: Primary readable text — 15pt medium
    case body

    /// Body semibold: Emphasized body text — 15pt bold
    case bodySemibold

    /// Caption: Secondary small text — 13pt medium
    case caption

    /// Small: Very small text — 11.5pt medium
    case small

    /// Button text — 15pt bold
    case button

    /// Large body — 16pt medium
    case bodyLarge

    // MARK: - Mono (DM Mono — clinical numerals)

    /// Mono: All numeric vitals, times, doses, percentages
    case mono

    // MARK: - Font Properties

    var font: Font {
        switch self {
        case .h1:
            return .custom("Fraunces-Medium", size: 33)
        case .h2:
            return .custom("Fraunces-Medium", size: 22)
        case .h3:
            return .custom("Fraunces-Medium", size: 17)
        case .labelCaps:
            return .custom("PlusJakartaSans-Bold", size: 11)
        case .body:
            return .custom("PlusJakartaSans-Medium", size: 15)
        case .bodySemibold:
            return .custom("PlusJakartaSans-Bold", size: 15)
        case .caption:
            return .custom("PlusJakartaSans-Medium", size: 13)
        case .small:
            return .custom("PlusJakartaSans-Medium", size: 11.5)
        case .button:
            return .custom("PlusJakartaSans-Bold", size: 15)
        case .bodyLarge:
            return .custom("PlusJakartaSans-Medium", size: 16)
        case .mono:
            return .custom("DMMono-Medium", size: 15)
        }
    }

    var lineSpacing: CGFloat {
        switch self {
        case .h1: return 4
        case .h2: return 3
        case .h3: return 2
        case .body, .bodySemibold, .bodyLarge: return 5
        case .caption, .small: return 3
        case .labelCaps: return 1
        case .button: return 0
        case .mono: return 0
        }
    }

    /// h1 is sentence-case in Vital Calm; only labelCaps is uppercased.
    var isUppercased: Bool {
        switch self {
        case .labelCaps: return true
        default: return false
        }
    }

    var tracking: CGFloat {
        switch self {
        case .labelCaps: return 1.4
        default: return 0
        }
    }
}

// MARK: - View Modifier

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
    func appFont(_ style: AppFont) -> some View {
        modifier(AppFontModifier(style: style))
    }
}

// MARK: - Text Extension

extension Text {
    func styled(_ style: AppFont) -> some View {
        let baseText = style.isUppercased ? self.textCase(.uppercase) : self.textCase(nil)
        return baseText
            .font(style.font)
            .lineSpacing(style.lineSpacing)
            .tracking(style.tracking)
    }
}
