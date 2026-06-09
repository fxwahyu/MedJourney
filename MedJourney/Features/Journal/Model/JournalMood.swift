import SwiftUI

enum JournalMood: String, CaseIterable, Identifiable {
    case great   = "Great"
    case good    = "Good"
    case neutral = "Neutral"
    case tired   = "Tired"
    case anxious = "Anxious"
    case sick    = "Sick"
    case pain    = "Pain"

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .great:   return "🤩"
        case .good:    return "😊"
        case .neutral: return "😐"
        case .tired:   return "😴"
        case .anxious: return "😰"
        case .sick:    return "🤒"
        case .pain:    return "😣"
        }
    }

    /// Numeric score for trend charts (0 = worst, 6 = best)
    var score: Int {
        switch self {
        case .great:   return 6
        case .good:    return 5
        case .neutral: return 4
        case .tired:   return 3
        case .anxious: return 2
        case .sick:    return 1
        case .pain:    return 0
        }
    }

    var accentColor: Color {
        switch self {
        case .great:   return Color(hex: "FFB800")
        case .good:    return AppColors.brandDark
        case .neutral: return AppColors.textSecondary
        case .tired:   return Color(hex: "9B59B6")
        case .anxious: return AppColors.accentOrange
        case .sick:    return AppColors.error
        case .pain:    return Color(hex: "FF3333")
        }
    }

    var selectedBackground: Color {
        switch self {
        case .great:   return Color(hex: "FFF8E1")
        case .good:    return AppColors.brandPale
        case .neutral: return AppColors.surface2
        case .tired:   return Color(hex: "F3E5F5")
        case .anxious: return AppColors.accentOrangePale
        case .sick:    return AppColors.errorPale
        case .pain:    return Color(hex: "FFE5E5")
        }
    }

    var selectedBorder: Color {
        switch self {
        case .great:   return Color(hex: "FFB800").opacity(0.4)
        case .good:    return AppColors.brandSoft
        case .neutral: return AppColors.border
        case .tired:   return Color(hex: "9B59B6").opacity(0.4)
        case .anxious: return AppColors.accentOrange.opacity(0.4)
        case .sick:    return AppColors.error.opacity(0.4)
        case .pain:    return Color(hex: "FF3333").opacity(0.4)
        }
    }

    var showsPainSlider: Bool {
        switch self {
        case .great, .good: return false
        default: return true
        }
    }
}
