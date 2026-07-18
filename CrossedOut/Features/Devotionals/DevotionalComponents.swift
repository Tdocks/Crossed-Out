import SwiftUI

// MARK: - "Was this helpful?" control (shared by built-in + independent)

/// Records a helpful/not-helpful signal for a devotional. Best-effort;
/// optimistic UI, one tap. Feeds the future personalization loop.
struct HelpfulFeedbackControl: View {
    let source: DevotionalSource
    var devotionalID: UUID? = nil
    var userDevotionalID: UUID? = nil

    @State private var choice: Bool? = nil
    @State private var submitting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Did you find this devotional helpful?")
                .font(.coUI(13, weight: .medium))
                .foregroundColor(.coInkSecondary)
            HStack(spacing: 12) {
                choiceButton(isHelpful: true, label: "Helpful", icon: .checkCircle, tint: .coOlive)
                choiceButton(isHelpful: false, label: "Not for me", icon: .crossOut, tint: .coInkSecondary)
            }
            if choice != nil {
                Text("Thanks — we'll use this to tune what we suggest next.")
                    .font(.coUI(12))
                    .foregroundColor(.coInkTertiary)
                    .transition(.opacity)
            }
        }
    }

    private func choiceButton(isHelpful: Bool, label: String,
                              icon: COIconName, tint: Color) -> some View {
        let selected = (choice == isHelpful)
        return Button {
            guard !submitting else { return }
            withAnimation(.easeOut(duration: 0.2)) { choice = isHelpful }
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            submitting = true
            Task {
                await SupabaseService.shared.submitDevotionalFeedback(
                    source: source, devotionalID: devotionalID,
                    userDevotionalID: userDevotionalID, helpful: isHelpful)
                submitting = false
            }
        } label: {
            HStack(spacing: 8) {
                COIcon(icon, size: 16, color: selected ? .white : tint)
                Text(label)
                    .font(.coUI(13, weight: .medium))
                    .foregroundColor(selected ? .white : .coInkSecondary)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background(selected ? tint : Color.coPaperSecondary)
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(Color.coDivider, lineWidth: selected ? 0 : 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Built-in devotional detail

struct DevotionalDetailView: View {
    let devotional: Devotional

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(devotional.verseRef.uppercased())
                    .font(.coUI(12, weight: .medium))
                    .tracking(1.4)
                    .foregroundColor(.coCrossRed)

                Text(devotional.title)
                    .font(.coDisplay(26, weight: .semibold))
                    .foregroundColor(.coInk)
                    .fixedSize(horizontal: false, vertical: true)

                Text(devotional.body)
                    .font(.coScripture(17))
                    .foregroundColor(.coInkSecondary)
                    .lineSpacing(7)
                    .fixedSize(horizontal: false, vertical: true)

                if let prompt = devotional.prompt, !prompt.isEmpty {
                    COCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                COIcon(.leaf, size: 16, color: .coOlive)
                                Text("Reflect")
                                    .font(.coUI(13, weight: .semibold))
                                    .foregroundColor(.coInk)
                            }
                            Text(prompt)
                                .font(.coScripture(15, italic: true))
                                .foregroundColor(.coInkSecondary)
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                COCard {
                    HelpfulFeedbackControl(source: .builtin, devotionalID: devotional.id)
                }
            }
            .padding(22)
        }
        .background(Color.coPaper.ignoresSafeArea())
        .navigationTitle("Today's Devotional")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task { await SupabaseService.shared.recordCompletion(kind: "devotional") }
        }
    }
}

// MARK: - User (independent study) devotional detail

struct UserDevotionalDetailView: View {
    let devotional: UserDevotional

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(devotional.verseRef.uppercased())
                    .font(.coUI(12, weight: .medium))
                    .tracking(1.4)
                    .foregroundColor(.coCrossRed)

                Text(devotional.title?.isEmpty == false ? devotional.title! : "Independent study")
                    .font(.coDisplay(24, weight: .semibold))
                    .foregroundColor(.coInk)
                    .fixedSize(horizontal: false, vertical: true)

                Text("YOUR NOTES")
                    .font(.coUI(11, weight: .medium))
                    .tracking(1.2)
                    .foregroundColor(.coInkTertiary)

                Text(devotional.notes)
                    .font(.coScripture(16))
                    .foregroundColor(.coInkSecondary)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)

                COCard {
                    HelpfulFeedbackControl(source: .independent, userDevotionalID: devotional.id)
                }
            }
            .padding(22)
        }
        .background(Color.coPaper.ignoresSafeArea())
        .navigationTitle("Devotional")
        .navigationBarTitleDisplayMode(.inline)
    }
}
