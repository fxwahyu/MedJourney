//
//  AppShadows.swift
//  MedJourney
//
//  Design System — Shadow definitions (Vital Calm)
//

import SwiftUI

/// Shadow levels from the Vital Calm design spec.
///
/// Shadows are warmer and softer than the previous Jade Morning theme.
enum AppShadowLevel {

    /// Subtle card shadow — `0 5px 18px rgba(25,35,31,.05)`
    case card

    /// Elevated card shadow — for interactive/important cards
    case elevated

    /// FAB shadow — strong brand shadow for floating button
    case fab

    /// Bottom sheet shadow — upward shadow for overlays
    case bottomSheet

    /// No shadow
    case none

    // MARK: - Shadow Properties

    var color: Color {
        switch self {
        case .card:
            return Color(hex: "19231F").opacity(0.06)
        case .elevated:
            return AppColors.brand.opacity(0.12)
        case .fab:
            return AppColors.brand.opacity(0.34)
        case .bottomSheet:
            return Color(hex: "19231F").opacity(0.18)
        case .none:
            return Color.clear
        }
    }

    var radius: CGFloat {
        switch self {
        case .card: return 10
        case .elevated: return 20
        case .fab: return 24
        case .bottomSheet: return 40
        case .none: return 0
        }
    }

    var x: CGFloat { 0 }

    var y: CGFloat {
        switch self {
        case .card: return 4
        case .elevated: return 6
        case .fab: return 10
        case .bottomSheet: return -10
        case .none: return 0
        }
    }
}

// MARK: - View Extension

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
    func appShadow(_ level: AppShadowLevel) -> some View {
        modifier(AppShadowModifier(level: level))
    }
}
