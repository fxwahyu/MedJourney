//
//  AppSpacing.swift
//  MedJourney
//
//  Design System — Spacing and radius tokens (Vital Calm)
//

import SwiftUI

/// Spacing tokens — 4-pt grid scale (unchanged from Jade Morning).
enum AppSpacing {

    /// 4pt — Minimal spacing
    static let xs: CGFloat = 4

    /// 8pt — Small spacing
    static let sm: CGFloat = 8

    /// 12pt — Medium spacing
    static let md: CGFloat = 12

    /// 16pt — Large spacing
    static let lg: CGFloat = 16

    /// 20pt — Extra large spacing
    static let xl: CGFloat = 20

    /// 24pt — Double extra large
    static let xxl: CGFloat = 24

    /// 32pt — Triple extra large
    static let xxxl: CGFloat = 32

    /// 40pt — Huge spacing
    static let huge: CGFloat = 40

    /// 48pt — Maximum spacing
    static let max: CGFloat = 48
}

/// Corner radius tokens — Vital Calm scale.
enum AppRadius {

    /// 10pt — Subtle rounding (chips, small buttons)
    static let xs: CGFloat = 10

    /// 14pt — Small radius (inputs, small cards)
    static let sm: CGFloat = 14

    /// 18pt — Medium radius (text fields, medium cards)
    static let md: CGFloat = 18

    /// 22pt — Large radius (large cards)
    static let lg: CGFloat = 22

    /// 26pt — Extra large radius (primary cards, feature cards)
    static let xl: CGFloat = 26

    /// 999pt — Full pill shape (badges, tags, capsules)
    static let pill: CGFloat = 999

    /// 40pt — Bottom sheet and screen-matching top corners
    static let screen: CGFloat = 40
}
