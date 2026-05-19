//
//  AppColors.swift
//  MedJourney
//
//  Design System — Color palette tokens from Jade Morning theme
//

import SwiftUI

/// Centralized color palette for the app.
///
/// All colors are from the **Jade Morning** theme defined in the Figma spec.
/// Access colors via the static properties: `AppColors.brand`, `AppColors.accentOrange`, etc.
///
/// To add a new theme, create a theme provider that switches between
/// color sets — the `AppColors` abstraction makes this seamless.
enum AppColors {

    // MARK: - Brand Colors

    /// Primary brand color — Jade green
    static let brand = Color(hex: "00C48C")

    /// Darker variant of the brand color
    static let brandDark = Color(hex: "00A577")

    /// Deepest brand variant — used for emphasis
    static let brandDeeper = Color(hex: "007A58")

    /// Very light brand tint — backgrounds, subtle fills
    static let brandPale = Color(hex: "E0FBF3")

    /// Soft brand tint — slightly more visible than pale
    static let brandSoft = Color(hex: "B3F0DC")

    // MARK: - Accent Colors

    /// Orange accent — streaks, urgency, attention
    static let accentOrange = Color(hex: "FF8C42")

    /// Light orange background
    static let accentOrangePale = Color(hex: "FFF0E6")

    /// Violet accent — data, insights, secondary actions
    static let accentViolet = Color(hex: "7C6AF7")

    /// Light violet background
    static let accentVioletPale = Color(hex: "EEECFF")

    // MARK: - Surfaces

    /// Main background color
    static let background = Color(hex: "F4FBF8")

    /// Primary surface (cards, sheets)
    static let surface = Color.white

    /// Secondary surface — subtle contrast
    static let surface2 = Color(hex: "EEF8F4")

    // MARK: - Text Hierarchy

    /// Primary text — headings, important content
    static let textPrimary = Color(hex: "1A2E27")

    /// Secondary text — body, descriptions
    static let textSecondary = Color(hex: "5A7A6E")

    /// Tertiary text — captions, placeholders, inactive
    static let textTertiary = Color(hex: "92AFA5")

    // MARK: - Semantic Colors

    /// Success state
    static let success = Color(hex: "00C48C")

    /// Warning state
    static let warning = Color(hex: "FF8C42")

    /// Error / destructive state
    static let error = Color(hex: "FF6B6B")

    /// Error background
    static let errorPale = Color(hex: "FFF0F0")

    // MARK: - Dividers & Borders

    /// Subtle divider — brand at 8% opacity
    static let divider = brand.opacity(0.08)

    /// Default border color
    static let border = brand.opacity(0.15)
}

// MARK: - Color Extension for Hex Initialization

extension Color {

    /// Creates a `Color` from a hex string.
    ///
    /// Supports 6-character hex codes (RGB) with or without `#` prefix.
    ///
    /// - Parameter hex: The hex color string (e.g., "00C48C" or "#00C48C").
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let r, g, b: UInt64
        switch hex.count {
        case 6: // RGB
            (r, g, b) = (
                (int >> 16) & 0xFF,
                (int >> 8) & 0xFF,
                int & 0xFF
            )
        case 8: // ARGB
            (r, g, b) = (
                (int >> 16) & 0xFF,
                (int >> 8) & 0xFF,
                int & 0xFF
            )
        default:
            (r, g, b) = (0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }
}
