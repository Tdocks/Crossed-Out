import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var appState: AppState

    private enum Step { case welcome, focus, need }

    @State private var step: Step = .welcome
    @State private var selectedFocus: Set<String> = []
    @State private var needText: String = ""
    @State private var selectedMood: Mood?

    var body: some View {
        ZStack {
            Color.coPaper.ignoresSafeArea()
            switch step {
            case .welcome: welcome
            case .focus: focusStep
            case .need: needStep
            }
        }
        .animation(.easeInOut(duration: 0.25), value: step)
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
                    Task { await appState.completeOnboarding(name: MockData.profile.firstName,
                                                             focus: MockData.profile.focusAreas,
                                                             need: MockData.profile.need) }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
    }

    private var photoPlaceholder: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(colors: [Color.coPaperSecondary, Color.coDivider],
                                   startPoint: .top, endPoint: .bottom)
                )
            MountainSilhouette()
                .fill(Color.coInkTertiary.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .frame(height: 220)
    }

    // MARK: - Focus Step

    private var focusStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            stepHeader(title: "What matters to you\nright now?",
                       subtitle: "Choose a few. We'll shape your journey around them.")

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 10)],
                          alignment: .leading, spacing: 10) {
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

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 10)],
                              alignment: .leading, spacing: 10) {
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
                Task {
                    await appState.completeOnboarding(
                        name: MockData.profile.firstName,
                        focus: Array(selectedFocus),
                        need: needText.isEmpty ? MockData.profile.need : needText
                    )
                }
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

// MARK: - Mountain Silhouette

struct MountainSilhouette: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        p.move(to: CGPoint(x: 0, y: h))
        p.addLine(to: CGPoint(x: w * 0.18, y: h * 0.58))
        p.addLine(to: CGPoint(x: w * 0.30, y: h * 0.72))
        p.addLine(to: CGPoint(x: w * 0.48, y: h * 0.40))
        p.addLine(to: CGPoint(x: w * 0.63, y: h * 0.66))
        p.addLine(to: CGPoint(x: w * 0.78, y: h * 0.50))
        p.addLine(to: CGPoint(x: w, y: h * 0.78))
        p.addLine(to: CGPoint(x: w, y: h))
        p.closeSubpath()
        return p
    }
}
