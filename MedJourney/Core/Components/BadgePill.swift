//
//  BadgePill.swift
//  MedJourney
//
//  Components — Small tag/badge pill
//

import SwiftUI

/// A small pill-shaped badge for tags, labels, and status indicators.
struct BadgePill: View {

    enum Style {
        case brand, accent, violet, neutral
        case custom(bg: Color, fg: Color)

        var backgroundColor: Color {
            switch self {
            case .brand: return AppColors.brandPale
            case .accent: return AppColors.accentOrangePale
            case .violet: return AppColors.accentVioletPale
            case .neutral: return AppColors.surface2
            case .custom(let bg, _): return bg
            }
        }

        var foregroundColor: Color {
            switch self {
            case .brand: return AppColors.brandDark
            case .accent: return AppColors.accentOrange
            case .violet: return AppColors.accentViolet
            case .neutral: return AppColors.textSecondary
            case .custom(_, let fg): return fg
            }
        }
    }

    let text: String
    let style: Style
    let icon: String?

    init(_ text: String, style: Style = .brand, icon: String? = nil) {
        self.text = text
        self.style = style
        self.icon = icon
    }

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
            }
            Text(text)
                .appFont(.small)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs)
        .foregroundStyle(style.foregroundColor)
        .background(style.backgroundColor)
        .clipShape(Capsule())
    }
}

#Preview("Badge Variants") {
    HStack(spacing: AppSpacing.sm) {
        BadgePill("Symptom", style: .accent)
        BadgePill("Checkup", style: .violet)
        BadgePill("AI ready", style: .brand, icon: "sparkles")
    }
    .padding()
}
