//
//  PainSliderView.swift
//  MedJourney
//
//  Components — Reusable pain level slider
//

import SwiftUI

/// A labeled slider for capturing discomfort level (0–100).
///
/// Shows a color-coded label (Mild → Severe) and "I'm good / Awful"
/// endpoints. Meant to appear conditionally when the user's mood
/// implies pain.
///
/// Usage:
/// ```swift
/// @State private var painLevel: Double = 0
///
/// PainSliderView(painLevel: $painLevel)
/// ```
struct PainSliderView: View {

    @Binding var painLevel: Double

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            // Header row
            HStack {
                Text("What's your pain level?")
                    .styled(.labelCaps)
                    .foregroundStyle(AppColors.textTertiary)
                Spacer()
                Text(painLevelLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(painLevelColor)
                    .animation(.easeInOut(duration: 0.2), value: painLevelLabel)
            }

            // Slider + endpoints
            VStack(spacing: AppSpacing.sm) {
                Slider(value: $painLevel, in: 0...100, step: 1)
                    .tint(painLevelColor)
                    .animation(.easeInOut(duration: 0.2), value: painLevelColor)

                HStack {
                    Text("I'm good")
                        .font(.system(size: 11))
                        .foregroundStyle(AppColors.textTertiary)
                    Spacer()
                    Text("Awful")
                        .font(.system(size: 11))
                        .foregroundStyle(AppColors.textTertiary)
                }
            }
            .padding(AppSpacing.lg)
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .stroke(AppColors.border, lineWidth: 1)
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Computed

    private var painLevelLabel: String {
        switch painLevel {
        case 0..<20: return "Mild"
        case 20..<50: return "Moderate"
        case 50..<80: return "Significant"
        default: return "Severe"
        }
    }

    private var painLevelColor: Color {
        switch painLevel {
        case 0..<20: return AppColors.brandDark
        case 20..<50: return AppColors.accentOrange
        case 50..<80: return AppColors.error.opacity(0.8)
        default: return AppColors.error
        }
    }
}

#Preview {
    @Previewable @State var level: Double = 35

    PainSliderView(painLevel: $level)
        .padding(AppSpacing.xxl)
        .background(AppColors.background)
}
