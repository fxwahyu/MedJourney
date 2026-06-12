import SwiftUI

// MARK: - AI Glow Border Modifier

/// Walking aurora border — the gradient rotates 360° continuously around the card edge.
/// Violet → blue → cyan → violet loop. Reserved exclusively for AI surfaces.
struct AIGlowModifier: ViewModifier {
    @State private var rotation: Double = 0
    var cornerRadius: CGFloat = AppRadius.xl

    func body(content: Content) -> some View {
        // Pre-compute the rotating aurora gradient once
        let auroraGradient = AngularGradient(
            colors: [
                AppColors.accentViolet,
                AppColors.sky,
                AppColors.aiCyan,
                AppColors.sky,
                AppColors.accentViolet,   // close the loop for a seamless spin
            ],
            center: .center,
            startAngle: .degrees(rotation),
            endAngle: .degrees(rotation + 360)
        )

        return content
            // Crisp aurora stroke — no blur, no drawingGroup (both cause visual artifacts or scroll lag)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(auroraGradient, lineWidth: 1.5)
                    .opacity(0.75)
            }
            // Ambient colour tint via shadow — GPU-composited, no extra render pass
            .shadow(color: AppColors.accentViolet.opacity(0.14), radius: 8, x: 0, y: 2)
            .onAppear {
                withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}

extension View {
    func aiGlow(cornerRadius: CGFloat = AppRadius.xl) -> some View {
        modifier(AIGlowModifier(cornerRadius: cornerRadius))
    }
}

// MARK: - AI Orbit Loader

struct AIOrbitLoader: View {
    @State private var outerRotation: Double = 0
    @State private var innerRotation: Double = 0
    @State private var pulse: CGFloat = 1.0

    var size: CGFloat = 56

    var body: some View {
        ZStack {
            Circle()
                .fill(AppColors.accentViolet.opacity(0.07))
                .frame(width: size * 1.7, height: size * 1.7)

            Circle()
                .fill(AppColors.sky.opacity(0.06))
                .frame(width: size * 1.3, height: size * 1.3)

            // Outer ring: violet → blue (aurora)
            Circle()
                .trim(from: 0.1, to: 0.82)
                .stroke(
                    LinearGradient(
                        colors: [AppColors.accentViolet, AppColors.sky],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(outerRotation))

            // Inner ring: blue → cyan (aurora)
            Circle()
                .trim(from: 0.2, to: 0.65)
                .stroke(
                    LinearGradient(
                        colors: [AppColors.sky, AppColors.aiCyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
                .frame(width: size * 0.65, height: size * 0.65)
                .rotationEffect(.degrees(-innerRotation))

            Image(systemName: "sparkles")
                .font(.system(size: size * 0.27, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [AppColors.accentViolet, AppColors.sky, AppColors.aiCyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .scaleEffect(pulse)
        }
        .onAppear {
            withAnimation(.linear(duration: 2.2).repeatForever(autoreverses: false)) {
                outerRotation = 360
            }
            withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
                innerRotation = 360
            }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                pulse = 1.25
            }
        }
    }
}

// MARK: - AI Loading Banner

struct AILoadingBanner: View {
    var message: String = "MedCare AI is reviewing…"

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            AIOrbitLoader(size: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(message)
                    .appFont(.bodySemibold)
                    .foregroundStyle(AppColors.textPrimary)
                Text("This may take a moment")
                    .appFont(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }

            Spacer()
        }
        .padding(AppSpacing.lg)
        .background(AppGradients.aiGlowSoft)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
        .aiGlow(cornerRadius: AppRadius.md)
    }
}

// MARK: - AI Sparkle Tag

/// Aurora-tinted pill for AI-generated surfaces.
struct AISparkleTag: View {
    var label: String = "MedCare AI"

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "sparkles")
                .font(.system(size: 9, weight: .bold))
            Text(label)
                .font(.system(size: 10, weight: .bold))
        }
        .foregroundStyle(
            LinearGradient(
                colors: [AppColors.accentViolet, AppColors.sky],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, 4)
        .background(AppColors.accentVioletPale)
        .clipShape(Capsule())
        .overlay {
            Capsule().stroke(AppColors.accentViolet.opacity(0.25), lineWidth: 1)
        }
    }
}

// MARK: - Floating Sparkle Decoration

struct FloatingSparkles: View {
    private struct SparklePoint: Identifiable {
        let id: Int
        let relX: CGFloat
        let relY: CGFloat
        let size: CGFloat
        let colorIndex: Int
    }

    private let points: [SparklePoint] = [
        SparklePoint(id: 0, relX: 0.08, relY: 0.2,  size: 7, colorIndex: 0),
        SparklePoint(id: 1, relX: 0.5,  relY: 0.08, size: 5, colorIndex: 1),
        SparklePoint(id: 2, relX: 0.92, relY: 0.25, size: 6, colorIndex: 2),
        SparklePoint(id: 3, relX: 0.78, relY: 0.7,  size: 5, colorIndex: 3),
    ]

    // Aurora trio + clay
    private let colors: [Color] = [
        AppColors.accentViolet,
        AppColors.sky,
        AppColors.aiCyan,
        AppColors.accentOrange,
    ]

    @State private var pulsing = false

    var body: some View {
        GeometryReader { geo in
            ForEach(points) { p in
                Image(systemName: p.id % 2 == 0 ? "sparkle" : "star.fill")
                    .font(.system(size: p.size))
                    .foregroundStyle(colors[p.colorIndex % colors.count].opacity(pulsing ? 0.7 : 0.2))
                    .position(x: geo.size.width * p.relX, y: geo.size.height * p.relY)
                    .scaleEffect(pulsing ? 1.1 : 0.85)
            }
        }
        .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: pulsing)
        .onAppear { pulsing = true }
    }
}

// MARK: - Gradient Feature Card

struct FeatureCard<Content: View>: View {
    let gradient: LinearGradient
    var cornerRadius: CGFloat = AppRadius.xl
    var minHeight: CGFloat = 0
    let content: Content

    init(
        gradient: LinearGradient,
        cornerRadius: CGFloat = AppRadius.xl,
        minHeight: CGFloat = 0,
        @ViewBuilder content: () -> Content
    ) {
        self.gradient = gradient
        self.cornerRadius = cornerRadius
        self.minHeight = minHeight
        self.content = content()
    }

    var body: some View {
        content
            .padding(AppSpacing.xl)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
            .background(gradient)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .appShadow(.elevated)
    }
}

// MARK: - Markdown Analysis Renderer

/// Renders the structured markdown produced by LLMTagService into a proper visual hierarchy.
///
/// Supported syntax:
/// - `### Heading` / `## Heading` / `# Heading` → styled section title
/// - `• Text` / `- Text` / `* Text`             → dot-prefixed bullet row
/// - Any other non-empty line                    → plain paragraph
struct MarkdownAnalysisView: View {
    let markdown: String

    private struct Section: Identifiable {
        let id: Int
        let heading: String?
        let items: [Item]

        enum Item {
            case bullet(String)
            case paragraph(String)
        }
    }

    private var sections: [Section] {
        var result: [Section] = []
        var currentHeading: String? = nil
        var currentItems: [Section.Item] = []

        for raw in markdown.components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }

            if line.hasPrefix("### ") || line.hasPrefix("## ") || line.hasPrefix("# ") {
                if currentHeading != nil || !currentItems.isEmpty {
                    result.append(Section(id: result.count, heading: currentHeading, items: currentItems))
                }
                currentHeading = String(line.drop(while: { $0 == "#" || $0 == " " }))
                currentItems = []
            } else if line.hasPrefix("• ") || line.hasPrefix("- ") || line.hasPrefix("* ") {
                currentItems.append(.bullet(String(line.dropFirst(2))))
            } else {
                currentItems.append(.paragraph(line))
            }
        }

        if currentHeading != nil || !currentItems.isEmpty {
            result.append(Section(id: result.count, heading: currentHeading, items: currentItems))
        }

        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            ForEach(sections) { section in
                VStack(alignment: .leading, spacing: 5) {
                    if let heading = section.heading {
                        Text(heading)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppColors.brandDark)
                            .padding(.bottom, 2)
                    }

                    ForEach(section.items.indices, id: \.self) { idx in
                        switch section.items[idx] {
                        case .bullet(let text):
                            HStack(alignment: .top, spacing: 8) {
                                Circle()
                                    .fill(AppColors.brandDark.opacity(0.4))
                                    .frame(width: 4, height: 4)
                                    .padding(.top, 6)
                                inlineText(text)
                            }
                        case .paragraph(let text):
                            inlineText(text)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func inlineText(_ text: String) -> some View {
        if let attributed = try? AttributedString(markdown: text) {
            Text(attributed)
                .font(.system(size: 13))
                .foregroundStyle(AppColors.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(AppColors.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Previews

#Preview("AI Components") {
    ScrollView {
        VStack(spacing: AppSpacing.xl) {
            AIOrbitLoader(size: 60)

            AILoadingBanner(message: "Analyzing your health documents...")

            AISparkleTag()

            Text("AI Powered Card")
                .appFont(.bodySemibold)
                .foregroundStyle(AppColors.textPrimary)
                .padding(AppSpacing.xxl)
                .frame(maxWidth: .infinity)
                .background(AppColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl))
                .aiGlow()

            FeatureCard(gradient: AppGradients.checklist) {
                Text("Checklist Card")
                    .foregroundStyle(AppColors.mintInk)
            }
        }
        .padding(AppSpacing.xxl)
    }
    .background(AppColors.background)
}
