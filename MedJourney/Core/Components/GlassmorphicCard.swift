//
//  GlassmorphicCard.swift
//  MedJourney
//
//  Components — Glassmorphism effect card for gradient backgrounds
//

import SwiftUI

/// A glassmorphic card with translucent background and blur.
///
/// Per Figma spec, glassmorphism is only used on dark/gradient backgrounds
/// (e.g., streak card, feel bar on the header).
struct GlassmorphicCard<Content: View>: View {

    let cornerRadius: CGFloat
    let content: Content

    init(
        cornerRadius: CGFloat = AppRadius.lg,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .padding(AppSpacing.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
            .background(Color.white.opacity(0.18))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            }
    }
}

#Preview {
    ZStack {
        AppGradients.header.ignoresSafeArea()
        GlassmorphicCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("CURRENT STREAK")
                    .styled(.labelCaps)
                    .foregroundStyle(.white.opacity(0.7))
                Text("7")
                    .font(.system(size: 52, weight: .light, design: .serif))
                    .foregroundStyle(.white)
                Text("days in a row")
                    .appFont(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding()
    }
}
