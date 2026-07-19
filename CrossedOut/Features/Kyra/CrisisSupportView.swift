import SwiftUI

// MARK: - Crisis detection (deterministic, on-device)

/// A purely deterministic, on-device phrase matcher that runs on every
/// outgoing Kyra message. No AI, no network — if a message suggests the user
/// may be in danger, the conversation shows real crisis resources
/// immediately, before and regardless of anything the model says.
enum CrisisCategory {
    case selfHarm
    case abuse
}

enum CrisisDetector {

    private static let selfHarmPhrases: [String] = [
        "kill myself", "killing myself", "suicide", "suicidal",
        "end my life", "ending my life", "end it all", "take my own life",
        "don't want to live", "dont want to live", "don't want to be alive",
        "dont want to be alive", "no reason to live", "better off dead",
        "better off without me", "hurt myself", "hurting myself",
        "harm myself", "harming myself", "self harm", "self-harm",
        "want to die", "wish i was dead", "wish i were dead"
    ]

    private static let abusePhrases: [String] = [
        "abusing me", "abuses me", "being abused", "is abusive",
        "hits me", "hitting me", "beats me", "beating me",
        "he hurts me", "she hurts me", "they hurt me",
        "domestic violence", "afraid of my husband", "afraid of my wife",
        "afraid of my partner", "scared of my husband", "scared of my wife",
        "scared of my partner", "not safe at home", "unsafe at home"
    ]

    /// Returns the matched category for a message, or nil. Self-harm takes
    /// priority when both match.
    static func detect(in text: String) -> CrisisCategory? {
        let normalized = text.lowercased()
        if selfHarmPhrases.contains(where: { normalized.contains($0) }) { return .selfHarm }
        if abusePhrases.contains(where: { normalized.contains($0) }) { return .abuse }
        return nil
    }
}

// MARK: - Crisis resources card

/// Warm, plain crisis interstitial shown inline in the Kyra conversation the
/// moment a crisis phrase is detected. Real actions (call/text) — never AI.
struct CrisisResourcesCard: View {
    let category: CrisisCategory

    @Environment(\.openURL) private var openURL

    var body: some View {
        COCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    COIcon(.heart, size: 16, color: .coCrossRed)
                    Text("You matter. Please reach out.")
                        .font(.coUI(14, weight: .semibold))
                        .foregroundColor(.coInk)
                }

                Text(message)
                    .font(.coUI(13))
                    .foregroundColor(.coInkSecondary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 8) {
                    ForEach(actions, id: \.title) { action in
                        Button {
                            if let url = URL(string: action.urlString) {
                                openURL(url)
                            }
                        } label: {
                            HStack {
                                Text(action.title)
                                    .font(.coUI(14, weight: .semibold))
                                    .foregroundColor(.white)
                                Spacer()
                                COIcon(.chevronRight, size: 14, color: .white)
                            }
                            .padding(.horizontal, 14)
                            .frame(height: 44)
                            .background(Color.coCrossRed)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }

                Text("If you're in immediate danger, call 911.")
                    .font(.coUI(12))
                    .foregroundColor(.coInkTertiary)
            }
        }
    }

    private var message: String {
        switch category {
        case .selfHarm:
            return "What you're carrying sounds heavy — too heavy to hold alone. God has not crossed you out, and neither have we. Right now, the most faithful next step is talking with a real person who can help."
        case .abuse:
            return "No one should have to live afraid at home. God cares about your safety, and so do we. Trained advocates are available around the clock — confidential and free."
        }
    }

    private struct CrisisAction {
        let title: String
        let urlString: String
    }

    private var actions: [CrisisAction] {
        switch category {
        case .selfHarm:
            return [
                CrisisAction(title: "Call 988 — Suicide & Crisis Lifeline", urlString: "tel://988"),
                CrisisAction(title: "Text 988", urlString: "sms:988")
            ]
        case .abuse:
            return [
                CrisisAction(title: "Call the Domestic Violence Hotline", urlString: "tel://18007997233"),
                CrisisAction(title: "Text START to 88788", urlString: "sms:88788&body=START")
            ]
        }
    }
}

#Preview("Self-harm") {
    CrisisResourcesCard(category: .selfHarm)
        .padding(20)
        .background(Color.coPaper)
}

#Preview("Abuse") {
    CrisisResourcesCard(category: .abuse)
        .padding(20)
        .background(Color.coPaper)
}
