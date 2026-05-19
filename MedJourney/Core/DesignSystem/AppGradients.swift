//
//  AppGradients.swift
//  MedJourney
//
//  Design System — Gradient definitions
//

import SwiftUI

/// Pre-defined gradients from the Figma design spec.
///
/// The header gradient is the "brand signature" — every main screen
/// opens with it to anchor trust and consistency.
///
/// Usage:
/// ```swift
/// Rectangle()
///     .fill(AppGradients.header)
/// ```
enum AppGradients {

    /// Header gradient — the brand signature gradient (145°).
    ///
    /// Used on all main screen headers. Colors flow from
    /// brand → brandDark → brandDeeper.
    static let header = LinearGradient(
        colors: [
            AppColors.brand,
            AppColors.brandDark,
            AppColors.brandDeeper,
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Subtle brand gradient for card backgrounds.
    static let brandSubtle = LinearGradient(
        colors: [
            AppColors.brandPale,
            AppColors.brandSoft.opacity(0.5),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Accent gradient for attention-drawing elements.
    static let accent = LinearGradient(
        colors: [
            AppColors.accentOrange,
            AppColors.accentOrange.opacity(0.8),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Violet gradient for data/insights elements.
    static let violet = LinearGradient(
        colors: [
            AppColors.accentViolet,
            AppColors.accentViolet.opacity(0.8),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Glass overlay gradient for glassmorphism effects.
    static let glassOverlay = LinearGradient(
        colors: [
            Color.white.opacity(0.25),
            Color.white.opacity(0.08),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
