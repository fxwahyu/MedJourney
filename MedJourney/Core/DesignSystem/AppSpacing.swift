//
//  AppSpacing.swift
//  MedJourney
//
//  Design System — Spacing and radius tokens
//

import SwiftUI

/// Spacing tokens from the Figma design spec.
///
/// Use these consistently across all views to maintain
/// a cohesive visual rhythm.
///
/// Usage:
/// ```swift
/// .padding(AppSpacing.lg)
/// .padding(.horizontal, AppSpacing.xl)
/// ```
enum AppSpacing {

    // MARK: - Spacing Scale

    /// 4pt — Minimal spacing (between inline elements)
    static let xs: CGFloat = 4

    /// 8pt — Small spacing (icon gaps, tight padding)
    static let sm: CGFloat = 8

    /// 12pt — Medium spacing (form field gaps)
    static let md: CGFloat = 12

    /// 16pt — Large spacing (standard padding, section gaps)
    static let lg: CGFloat = 16

    /// 20pt — Extra large spacing (between sections)
    static let xl: CGFloat = 20

    /// 24pt — Double extra large (card internal padding)
    static let xxl: CGFloat = 24

    /// 32pt — Triple extra large (major section separators)
    static let xxxl: CGFloat = 32

    /// 40pt — Huge spacing (top-level layout margins)
    static let huge: CGFloat = 40

    /// 48pt — Maximum spacing
    static let max: CGFloat = 48
}

/// Corner radius tokens from the Figma design spec.
///
/// Usage:
/// ```swift
/// .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
/// ```
enum AppRadius {

    /// 8pt — Subtle rounding (small buttons, chips)
    static let xs: CGFloat = 8

    /// 12pt — Small radius (inputs, small cards)
    static let sm: CGFloat = 12

    /// 16pt — Medium radius (text fields, medium cards)
    static let md: CGFloat = 16

    /// 20pt — Large radius (text areas, large cards)
    static let lg: CGFloat = 20

    /// 24pt — Extra large radius (primary cards)
    static let xl: CGFloat = 24

    /// 100pt — Full pill shape (badges, tags)
    static let pill: CGFloat = 100

    /// 42pt — Phone frame corner matching (bottom sheet, tab bar)
    static let screen: CGFloat = 42
}
