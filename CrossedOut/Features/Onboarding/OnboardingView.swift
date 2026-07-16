import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var appState: AppState

    private enum Step { case welcome, focus, need, auth }

    @State private var step: Step = .welcome
    @State private var selectedFocus: Set<String> = []
    @State private var needText: String = ""
    @State private var selectedMood: Mood?
    @State private var authMode: AuthMode = .createAccount

    var body: some View {
        ZStack {
            Color.coPaper.ignoresSafeArea()
            switch step {
            case .welcome: welcome
            case .focus: focusStep
            case .need: needStep
            case .auth: authStep
            }
        }
        .animation(.easeInOut(duration: 0.25), value: step)
    }

    // MARK: - Auth Step

    /// The final, mandatory onboarding step. A real account (Sign in with
    /// Apple or email/password) is required before onboarding can complete —
    /// there is no anonymous fallback and no way to skip this step.
    private var authStep: some View {
        VStack(spacing: 0) {
            backButton
            AuthSheet(mode: authMode) {
                switch authMode {
                case .signIn:
                    // Returning user: adopt their existing remote profile.
                    appState.refreshAfterAuth()
                case .createAccount:
                    // New user: persist the onboarding wizard's selections
                    // now that a real account backs them.
                    Task {
                        await appState.completeOnboarding(
                            name: MockData.profile.firstName,
                            focus: Array(selectedFocus),
                            need: needText.isEmpty ? MockData.profile.need : needText
                        )
                    }
                }
            }
        }
    }

    private var backButton: some View {
        HStack {
            Button {
                step = (authMode == .signIn) ? .welcome : .need
            } label: {
                Text("Back")
                    .font(.coUI(14))
                    .foregroundColor(.coInkSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }

    // MARK: - Welcome

    private var welcome: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 40)
            COBrandWordmark(size: 44)
                .frame(maxWidth: .infinity)
                .padding(.top, 24)

            Text("A space to grow closer to God,\nconnect with others, and live on mission.")
                .font(.coScripture(20, italic: true))
                .foregroundColor(.coInkSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 32)
                .padding(.top, 22)

            photoPlaceholder
                .padding(.horizontal, 24)
                .padding(.top, 32)

            Spacer()

            VStack(spacing: 6) {
                COPrimaryButton(title: "Get Started") { step = .focus }
                COSecondaryButton(title: "I already have an account") {
                    authMode = .signIn
                    step = .auth
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
    }

    /// A quiet editorial illustration: a hiker on a near ridge, gazing left
    /// toward a distant cross, backed by a soft dawn sky. Built entirely from
    /// SwiftUI shapes/gradients so it reads in both light and dark mode via
    /// the existing color tokens.
    private var photoPlaceholder: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // (a) Sky
                LinearGradient(colors: [Color.coPaperSecondary, Color.coDivider],
                               startPoint: .top, endPoint: .bottom)

                // Soft sun glow, upper right
                RadialGradient(colors: [Color.coGold.opacity(0.25), Color.coGold.opacity(0)],
                               center: UnitPoint(x: 0.8, y: 0.18),
                               startRadius: 2, endRadius: h * 0.6)

                // (b) Far ridge — lightest, smallest
                RidgeShape(points: OnboardingArt.farRidge)
                    .fill(Color.coInkTertiary.opacity(0.18))

                // (e) Thin monoline cross planted on the far ridge peak
                ThinCrossShape()
                    .stroke(Color.coCrossRed.opacity(0.6),
                            style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
                    .frame(width: w * 0.028, height: h * 0.12)
                    .position(x: w * 0.40, y: h * 0.34 - h * 0.05)

                // (d) Mist band between far and mid ridges
                LinearGradient(colors: [Color.white.opacity(0.08), Color.white.opacity(0)],
                               startPoint: .top, endPoint: .bottom)
                    .frame(width: w, height: h * 0.08)
                    .position(x: w * 0.5, y: h * 0.52)

                // (b) Mid ridge
                RidgeShape(points: OnboardingArt.midRidge)
                    .fill(Color.coInkTertiary.opacity(0.30))

                // (d) Mist band between mid and close ridges
                LinearGradient(colors: [Color.coPaper.opacity(0.5), Color.coPaper.opacity(0)],
                               startPoint: .top, endPoint: .bottom)
                    .frame(width: w, height: h * 0.08)
                    .position(x: w * 0.5, y: h * 0.70)

                // (b) Close ridge — darkest, largest
                RidgeShape(points: OnboardingArt.closeRidge)
                    .fill(Color.coInkTertiary.opacity(0.45))

                // (c) Standing hiker with backpack, right-of-center, gazing
                // left toward the distant cross
                HikerSilhouetteShape()
                    .fill(Color.coInk.opacity(0.7))
                    .frame(width: w * 0.045, height: 36)
                    .position(x: w * 0.66, y: h * 0.80 - 18)
            }
        }
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Focus Step

    private var focusStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            stepHeader(title: "What matters to you\nright now?",
                       subtitle: "Choose a few. We'll shape your journey around them.")

            ScrollView {
                COFlowLayout(hSpacing: 10, vSpacing: 10) {
                    ForEach(MockData.focusAreas) { area in
                        COChip(text: area.name, selected: selectedFocus.contains(area.name)) {
                            toggleFocus(area.name)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }

            COPrimaryButton(title: "Continue") { step = .need }
                .disabled(selectedFocus.isEmpty)
                .opacity(selectedFocus.isEmpty ? 0.5 : 1)
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
        }
        .padding(.top, 20)
    }

    private func toggleFocus(_ name: String) {
        if selectedFocus.contains(name) { selectedFocus.remove(name) }
        else { selectedFocus.insert(name) }
    }

    // MARK: - Need Step

    private var needStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            stepHeader(title: "What do you need\nmost right now?",
                       subtitle: "Say it plainly. This stays between you and God.")

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    TextField("I need…", text: $needText, axis: .vertical)
                        .font(.coUI(16))
                        .foregroundColor(.coInk)
                        .lineLimit(3, reservesSpace: true)
                        .padding(14)
                        .background(Color.coCard)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.coDivider, lineWidth: 1)
                        )

                    Text("How are you feeling?")
                        .font(.coUI(14, weight: .medium))
                        .foregroundColor(.coInkSecondary)

                    COFlowLayout(hSpacing: 10, vSpacing: 10) {
                        ForEach(MockData.moodTones) { mood in
                            COChip(text: mood.label, selected: selectedMood == mood) {
                                selectedMood = mood
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }

            COPrimaryButton(title: "Begin") {
                // A real account is required to finish onboarding — no
                // anonymous fallback and no way to skip the auth step.
                authMode = .createAccount
                step = .auth
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .padding(.top, 20)
    }

    // MARK: - Shared

    private func stepHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.coDisplay(28, weight: .semibold))
                .foregroundColor(.coInk)
                .fixedSize(horizontal: false, vertical: true)
            Text(subtitle)
                .font(.coUI(15))
                .foregroundColor(.coInkSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
    }
}

// MARK: - Onboarding Art

/// Shared ridge-line data for the welcome illustration, expressed as
/// fractional (0...1) points across the frame so RidgeShape can scale to
/// any container size.
private enum OnboardingArt {
    static let farRidge: [CGPoint] = [
        CGPoint(x: 0, y: 0.55), CGPoint(x: 0.14, y: 0.42), CGPoint(x: 0.28, y: 0.50),
        CGPoint(x: 0.40, y: 0.34), CGPoint(x: 0.55, y: 0.48), CGPoint(x: 0.70, y: 0.38),
        CGPoint(x: 0.85, y: 0.50), CGPoint(x: 1, y: 0.44)
    ]
    static let midRidge: [CGPoint] = [
        CGPoint(x: 0, y: 0.75), CGPoint(x: 0.16, y: 0.60), CGPoint(x: 0.33, y: 0.68),
        CGPoint(x: 0.50, y: 0.55), CGPoint(x: 0.68, y: 0.65), CGPoint(x: 0.85, y: 0.58),
        CGPoint(x: 1, y: 0.70)
    ]
    static let closeRidge: [CGPoint] = [
        CGPoint(x: 0, y: 0.95), CGPoint(x: 0.18, y: 0.80), CGPoint(x: 0.35, y: 0.88),
        CGPoint(x: 0.52, y: 0.74), CGPoint(x: 0.66, y: 0.80), CGPoint(x: 0.85, y: 0.76),
        CGPoint(x: 1, y: 0.90)
    ]
}

/// A ridge silhouette built from fractional points (0...1 of the rect),
/// filled from the ridge line down to the bottom of the frame.
struct RidgeShape: Shape {
    let points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var p = Path()
        guard let first = points.first else { return p }
        p.move(to: CGPoint(x: 0, y: rect.height))
        p.addLine(to: CGPoint(x: first.x * rect.width, y: first.y * rect.height))
        for pt in points.dropFirst() {
            p.addLine(to: CGPoint(x: pt.x * rect.width, y: pt.y * rect.height))
        }
        p.addLine(to: CGPoint(x: rect.width, y: rect.height))
        p.closeSubpath()
        return p
    }
}

/// A thin two-stroke monoline cross (vertical beam + upper crossbar).
struct ThinCrossShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.32))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.32))
        return p
    }
}

/// A simple standing hiker silhouette: head, tapered torso, small backpack
/// bump, and a slight walking stance.
struct HikerSilhouetteShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()

        let headR = w * 0.6
        p.addEllipse(in: CGRect(x: rect.midX - headR / 2, y: rect.minY, width: headR, height: headR))

        p.move(to: CGPoint(x: rect.minX + w * 0.10, y: rect.minY + h * 0.30))
        p.addLine(to: CGPoint(x: rect.minX + w * 0.90, y: rect.minY + h * 0.30))
        p.addLine(to: CGPoint(x: rect.minX + w * 0.78, y: rect.minY + h * 0.62))
        p.addLine(to: CGPoint(x: rect.minX + w * 0.22, y: rect.minY + h * 0.62))
        p.closeSubpath()

        p.addRoundedRect(
            in: CGRect(x: rect.minX + w * 0.55, y: rect.minY + h * 0.32,
                       width: w * 0.55, height: h * 0.26),
            cornerSize: CGSize(width: w * 0.15, height: w * 0.15)
        )

        p.move(to: CGPoint(x: rect.minX + w * 0.30, y: rect.minY + h * 0.62))
        p.addLine(to: CGPoint(x: rect.minX + w * 0.05, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + w * 0.35, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + w * 0.48, y: rect.minY + h * 0.62))
        p.closeSubpath()

        p.move(to: CGPoint(x: rect.minX + w * 0.60, y: rect.minY + h * 0.62))
        p.addLine(to: CGPoint(x: rect.minX + w * 0.85, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + w * 0.55, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + w * 0.52, y: rect.minY + h * 0.62))
        p.closeSubpath()

        return p
    }
}
