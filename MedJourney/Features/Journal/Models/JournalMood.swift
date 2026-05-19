//
//  JournalMood.swift
//  MedJourney
//
//  Feature: Journal — Mood model used in journal entries
//

import SwiftUI

/// Represents a user's self-reported mood when creating a journal entry.
///
/// Drives the `MoodSelectorView` and conditionally shows the `PainSliderView`
/// for moods that imply discomfort (all except `.fit`).
enum JournalMood: String, CaseIterable, Identifiable {
    case sick = "Sick"
    case low = "Low"
    case neutral = "Neutral"
    case fit = "Fit"

    var id: String { rawValue }

    /// Emoji for display — must be rendered without any foregroundStyle on parent
    var emoji: String {
        switch self {
        case .sick:    return "\u{1F912}" // 🤒
        case .low:     return "\u{1F614}" // 😔
        case .neutral: return "\u{1F610}" // 😐
        case .fit:     return "\u{1F60A}" // 😊
        }
    }

    /// SF Symbol fallback (used only if needed)
    var symbolName: String {
        switch self {
        case .sick:    return "thermometer.medium"
        case .low:     return "cloud.drizzle"
        case .neutral: return "minus.circle"
        case .fit:     return "sun.max"
        }
    }

    /// Accent color for the selected state
    var accentColor: Color {
        switch self {
        case .sick:    return AppColors.error
        case .low:     return AppColors.accentOrange
        case .neutral: return AppColors.textSecondary
        case .fit:     return AppColors.brandDark
        }
    }

    var selectedBackground: Color {
        switch self {
        case .sick:    return AppColors.errorPale
        case .low:     return AppColors.accentOrangePale
        case .neutral: return AppColors.surface2
        case .fit:     return AppColors.brandPale
        }
    }

    var selectedBorder: Color {
        switch self {
        case .sick:    return AppColors.error.opacity(0.4)
        case .low:     return AppColors.accentOrange.opacity(0.4)
        case .neutral: return AppColors.border
        case .fit:     return AppColors.brandSoft
        }
    }

    /// Whether this mood should reveal the `PainSliderView`
    var showsPainSlider: Bool { self != .fit }
}
