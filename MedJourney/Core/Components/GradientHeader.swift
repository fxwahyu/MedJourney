//
//  GradientHeader.swift
//  MedJourney
//
//  Components — Reusable gradient header with decorative circles
//

import SwiftUI

/// A gradient header matching the Figma brand signature.
///
/// Every main screen opens with this gradient to anchor trust and consistency.
/// Includes decorative semi-transparent circles for depth.
struct GradientHeader<Content: View>: View {

    let height: CGFloat
    let content: Content

    init(height: CGFloat = 280, @ViewBuilder content: () -> Content) {
        self.height = height
        self.content = content()
    }

    var body: some View {
        ZStack {
            // Gradient background
            AppGradients.header
                .ignoresSafeArea(edges: .top)

            // Decorative circles for depth
            Circle()
                .fill(Color.white.opacity(0.07))
                .frame(width: 200, height: 200)
                .offset(x: 100, y: -60)

            Circle()
                .fill(Color.white.opacity(0.05))
                .frame(width: 120, height: 120)
                .offset(x: -130, y: 20)

            // Content
            VStack {
                content
            }
            .padding(.horizontal, AppSpacing.xxl)
        }
        .frame(height: height)
    }
}

#Preview {
    VStack(spacing: 0) {
        GradientHeader {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("Good morning ✦")
                    .styled(.labelCaps)
                    .foregroundStyle(.white.opacity(0.7))
                Text("MedJournal")
                    .appFont(.h2)
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        Spacer()
    }
    .background(AppColors.background)
}
