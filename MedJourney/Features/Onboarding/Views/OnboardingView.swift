import SwiftUI
import SwiftData

struct OnboardingView: View {
    @AppStorage("hasOnboarded") private var hasOnboarded = false
    @State private var currentPage = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(id: 0,
            wash: AppColors.brand,
            kicker: "Welcome to MedJourney",
            title: "Your health, gently understood.",
            body: "A calm place to journal how you feel, track vitals, and keep every checkup in one trusted record.",
            artKind: .journal,
            isAI: false),
        OnboardingPage(id: 1,
            wash: AppColors.indigo,
            kicker: "Meet MedCare AI",
            title: "A companion that notices what matters.",
            body: "MedCare AI reads your patterns and surfaces gentle nudges — never a diagnosis, always a thoughtful conversation starter for your doctor.",
            artKind: .ai,
            isAI: true),
        OnboardingPage(id: 2,
            wash: AppColors.checkupTeal,
            kicker: "Private by design",
            title: "Stays on your device.",
            body: "Documents are summarized on-device first. Only anonymized trends ever leave your phone — never raw records.",
            artKind: .shield,
            isAI: false),
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            AppColors.background.ignoresSafeArea()

            TabView(selection: $currentPage) {
                ForEach(pages) { page in
                    OnboardingPageView(page: page)
                        .tag(page.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            bottomControls
        }
    }

    // MARK: - Footer

    private var bottomControls: some View {
        VStack(spacing: AppSpacing.xl) {
            // Page dots
            HStack(spacing: 7) {
                ForEach(pages) { page in
                    Capsule()
                        .fill(currentPage == page.id
                              ? pages[currentPage].wash
                              : AppColors.border)
                        .frame(width: currentPage == page.id ? 22 : 6, height: 6)
                        .animation(.spring(duration: 0.3), value: currentPage)
                }
            }

            // Buttons row
            HStack(spacing: AppSpacing.md) {
                Button("Skip") { hasOnboarded = true }
                    .appFont(.bodySemibold)
                    .foregroundStyle(AppColors.textTertiary)
                    .padding(.horizontal, AppSpacing.sm)

                Spacer()

                Button {
                    if currentPage < pages.count - 1 {
                        withAnimation(.easeInOut(duration: 0.3)) { currentPage += 1 }
                    } else {
                        withAnimation(.spring(duration: 0.5)) { hasOnboarded = true }
                    }
                } label: {
                    HStack(spacing: AppSpacing.sm) {
                        Text(currentPage < pages.count - 1 ? "Continue" : "Get started")
                            .appFont(.button)
                        Image(systemName: currentPage < pages.count - 1 ? "chevron.right" : "arrow.right")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, AppSpacing.xl)
                    .padding(.vertical, AppSpacing.md)
                    .background(
                        pages[currentPage].isAI
                            ? AnyShapeStyle(AppGradients.aiGlow)
                            : AnyShapeStyle(pages[currentPage].wash)
                    )
                    .clipShape(Capsule())
                    .appShadow(.elevated)
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(.horizontal, AppSpacing.xxxl)
        .padding(.bottom, 40)
    }
}

// MARK: - Page Model

struct OnboardingPage: Identifiable {
    let id: Int
    let wash: Color
    let kicker: String
    let title: String
    let body: String
    let artKind: ArtKind
    let isAI: Bool

    enum ArtKind { case journal, ai, shield }
}

// MARK: - Page View

struct OnboardingPageView: View {
    let page: OnboardingPage
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Brand mark + app name
            HStack(spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(AppColors.brand)
                        .frame(width: 30, height: 30)
                        .shadow(color: AppColors.brand.opacity(0.3), radius: 8, y: 4)
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                }
                Text("MedJourney")
                    .styled(.h3)
                    .foregroundStyle(AppColors.textPrimary)
            }
            .padding(.top, 78)
            .padding(.horizontal, AppSpacing.xxxl)

            Spacer().frame(height: AppSpacing.xxl)

            // Art card
            OnboardingArtView(kind: page.artKind, wash: page.wash)
                .padding(.horizontal, AppSpacing.xxxl)

            Spacer()

            // Text block
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                // Kicker label
                if page.isAI {
                    Text(page.kicker.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppColors.accentViolet, AppColors.sky],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                } else {
                    Text(page.kicker.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(page.wash)
                }

                // Serif title
                Text(page.title)
                    .font(.custom("Fraunces-Medium", size: 30))
                    .lineSpacing(2)
                    .foregroundStyle(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                // Body
                Text(page.body)
                    .appFont(.bodyLarge)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, AppSpacing.xxxl)
            .padding(.bottom, 140)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
        .onAppear {
            withAnimation(.easeOut(duration: 0.35)) { appeared = true }
        }
        .onDisappear { appeared = false }
    }
}

// MARK: - Art Views

struct OnboardingArtView: View {
    let kind: OnboardingPage.ArtKind
    let wash: Color

    var body: some View {
        Group {
            switch kind {
            case .journal: journalArt
            case .ai:      aiArt
            case .shield:  shieldArt
            }
        }
        .frame(height: 250)
        .clipShape(RoundedRectangle(cornerRadius: 28))
    }

    // Slide 1: brand-pale gradient with leaf icon
    private var journalArt: some View {
        ZStack {
            LinearGradient(
                colors: [AppColors.brandPale, .white],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            // Decorative circles
            Circle()
                .fill(AppColors.brandSoft.opacity(0.5))
                .frame(width: 150, height: 150)
                .offset(x: 60, y: -50)
            Circle()
                .fill(AppColors.accentOrangePale)
                .frame(width: 120, height: 120)
                .offset(x: -80, y: 60)
            // Icon tile
            ZStack {
                RoundedRectangle(cornerRadius: 30)
                    .fill(AppColors.surface)
                    .frame(width: 110, height: 110)
                    .shadow(color: AppColors.brand.opacity(0.2), radius: 24, y: 16)
                Image(systemName: "leaf.fill")
                    .font(.system(size: 52, weight: .light))
                    .foregroundStyle(AppColors.brand)
            }
        }
    }

    // Slide 2: aurora animated gradient with orbiting rings
    private var aiArt: some View {
        ZStack {
            LinearGradient(
                colors: [AppColors.accentViolet, AppColors.sky, AppColors.aiCyan],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            FloatingSparkles()
            // Outer orbit ring
            Circle()
                .stroke(Color.white.opacity(0.35), lineWidth: 1.5)
                .frame(width: 180, height: 180)
            // Inner orbit ring
            Circle()
                .stroke(Color.white.opacity(0.55), lineWidth: 1.5)
                .frame(width: 120, height: 120)
            // Center icon
            Image(systemName: "sparkles")
                .font(.system(size: 58, weight: .light))
                .foregroundStyle(.white.opacity(0.9))
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        }
    }

    // Slide 3: checkup-pale with dot pattern + shield
    private var shieldArt: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "E2F1F4"), .white],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            // Dot pattern overlay (simulated via circles)
            Canvas { context, size in
                let spacing: CGFloat = 20
                for col in 0...Int(size.width / spacing) + 1 {
                    for row in 0...Int(size.height / spacing) + 1 {
                        let x = CGFloat(col) * spacing
                        let y = CGFloat(row) * spacing
                        let dist = hypot(x - size.width / 2, y - size.height * 0.45)
                        let maxDist = min(size.width, size.height) * 0.7
                        let alpha = max(0, 1 - dist / maxDist) * 0.5
                        context.fill(
                            Path(ellipseIn: CGRect(x: x - 1, y: y - 1, width: 2, height: 2)),
                            with: .color(AppColors.checkupTeal.opacity(alpha))
                        )
                    }
                }
            }
            // Shield tile
            ZStack {
                RoundedRectangle(cornerRadius: 30)
                    .fill(AppColors.surface)
                    .frame(width: 110, height: 110)
                    .shadow(color: AppColors.checkupTeal.opacity(0.22), radius: 24, y: 16)
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 52, weight: .light))
                    .foregroundStyle(AppColors.checkupTeal)
            }
        }
    }
}

#Preview {
    OnboardingView()
        .modelContainer(SwiftDataContainer.create(inMemory: true))
}
