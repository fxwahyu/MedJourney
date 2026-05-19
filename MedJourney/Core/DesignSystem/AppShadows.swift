//
//  AppShadows.swift
//  MedJourney
//
//  Design System — Shadow definitions
//

import SwiftUI

/// Shadow levels from the Figma design spec.
///
/// Each level provides a pre-configured shadow suitable for
/// different UI elements (cards, elevated elements, FABs).
///
/// Usage:
/// ```swift
/// AppCard {
///     Text("Content")
/// }
/// .appShadow(.card)
/// ```
enum AppShadowLevel {

    /// Subtle card shadow — default for flat cards
    /// `0 2px 12px rgba(0,0,0,0.04)`
    case card

    /// Elevated card shadow — for interactive/important cards
    /// `0 4px 20px rgba(brand, 0.12)`
    case elevated

    /// FAB shadow — strong, colored shadow for floating buttons
    /// `0 8px 24px rgba(brand, 0.35)`
    case fab

    /// Bottom sheet shadow — upward shadow for overlays
    /// `0 -4px 40px rgba(0,0,0,0.12)`
    case bottomSheet

    /// No shadow
    case none

    // MARK: - Shadow Properties

    var color: Color {
        switch self {
        case .card:
            return Color.black.opacity(0.04)
        case .elevated:
            return AppColors.brand.opacity(0.12)
        case .fab:
            return AppColors.brand.opacity(0.35)
        case .bottomSheet:
            return Color.black.opacity(0.12)
        case .none:
            return Color.clear
        }
    }

    var radius: CGFloat {
        switch self {
        case .card: return 12
        case .elevated: return 20
        case .fab: return 24
        case .bottomSheet: return 40
        case .none: return 0
        }
    }

    var x: CGFloat { 0 }

    var y: CGFloat {
        switch self {
        case .card: return 2
        case .elevated: return 4
        case .fab: return 8
        case .bottomSheet: return -4
        case .none: return 0
        }
    }
}

// MARK: - View Extension

/// View modifier for applying app shadow levels.
struct AppShadowModifier: ViewModifier {
    let level: AppShadowLevel

    func body(content: Content) -> some View {
        content
            .shadow(
                color: level.color,
                radius: level.radius,
                x: level.x,
                y: level.y
            )
    }
}

extension View {

    /// Applies a pre-defined shadow level from the design system.
    ///
    /// - Parameter level: The shadow intensity level.
    /// - Returns: The view with the shadow applied.
    func appShadow(_ level: AppShadowLevel) -> some View {
        modifier(AppShadowModifier(level: level))
    }
}
