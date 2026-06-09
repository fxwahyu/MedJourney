//
//  AppColors.swift
//  MedJourney
//
//  Design System — Color palette tokens from Vital Calm theme
//

import SwiftUI

/// Centralized color palette for the app.
///
/// All colors are from the **Vital Calm** theme.
/// Spruce-teal primary on warm paper neutrals, clay accent,
/// and an AI "aurora" gradient reserved exclusively for AI surfaces.
enum AppColors {

    // MARK: - Brand Colors (Spruce Teal)

    /// Primary brand color — spruce teal
    static let brand = Color(hex: "137A6E")

    /// Darker variant of the brand color
    static let brandDark = Color(hex: "0D5C53")

    /// Deepest brand variant — used for emphasis
    static let brandDeeper = Color(hex: "08423B")

    /// Very light brand tint — backgrounds, subtle fills
    static let brandPale = Color(hex: "E3F1ED")

    /// Soft brand tint — slightly more visible than pale
    static let brandSoft = Color(hex: "C0E0D8")

    // MARK: - Accent Colors

    /// Clay accent — warm human accent (formerly accentOrange)
    static let accentOrange = Color(hex: "C77B53")

    /// Light clay background
    static let accentOrangePale = Color(hex: "F6E9DF")

    /// Aurora violet — AI surfaces only
    static let accentViolet = Color(hex: "8B6FE8")

    /// Light violet tint — AI surface backgrounds
    static let accentVioletPale = Color(hex: "EFEBFA")

    /// AI aurora — cyan endpoint (AI surfaces only)
    static let aiCyan = Color(hex: "2FB6C0")

    // MARK: - Surfaces

    /// Main background — warm paper
    static let background = Color(hex: "F4F2ED")

    /// Primary surface (cards, sheets)
    static let surface = Color.white

    /// Secondary surface — subtle warm contrast
    static let surface2 = Color(hex: "ECE9E1")

    // MARK: - Text Hierarchy

    /// Primary text — headings, important content
    static let textPrimary = Color(hex: "19231F")

    /// Secondary text — body, descriptions
    static let textSecondary = Color(hex: "57635E")

    /// Tertiary text — captions, placeholders, inactive
    static let textTertiary = Color(hex: "939B95")

    // MARK: - Semantic Colors

    /// Success state
    static let success = Color(hex: "2E9E6B")

    /// Warning state
    static let warning = Color(hex: "C2871F")

    /// Error / destructive state
    static let error = Color(hex: "C9544F")

    /// Error background
    static let errorPale = Color(hex: "F8E8E6")

    // MARK: - Extended Accents

    /// Rose — medicine category
    static let rose = Color(hex: "C0617B")

    /// Light rose background
    static let rosePale = Color(hex: "F7E7EC")

    /// Sky blue — aurora second stop (AI surfaces)
    static let sky = Color(hex: "5B8DEF")

    /// Light sky background
    static let skyPale = Color(hex: "E6EFF8")

    /// Indigo — insights category
    static let indigo = Color(hex: "7C6BD9")

    /// Amber — warning accent
    static let amber = Color(hex: "C2871F")

    /// Teal — checkup category
    static let checkupTeal = Color(hex: "2A93A6")

    /// Soft mint — daily checklist card background
    static let mintCard = Color(hex: "DCEFE9")

    /// Deeper mint — checklist gradient endpoint
    static let mintCardDeep = Color(hex: "C0E0D8")

    /// Deep spruce — text on mint backgrounds
    static let mintInk = Color(hex: "0D5C53")

    /// Pale violet — medicine card background
    static let lavenderCard = Color(hex: "E8E4F6")

    /// Deeper violet — medicine gradient endpoint
    static let lavenderCardDeep = Color(hex: "D9D2F0")

    /// Deep warm purple — text on lavender backgrounds
    static let lavenderInk = Color(hex: "4A3A6B")

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
    /// - Parameter hex: The hex color string (e.g., "137A6E" or "#137A6E").
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
