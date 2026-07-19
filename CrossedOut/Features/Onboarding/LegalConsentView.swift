import SwiftUI

// MARK: - Which legal document to show

enum LegalDoc: String, Identifiable {
    case terms, privacy
    var id: String { rawValue }

    var title: String {
        switch self {
        case .terms: return LegalDocuments.termsTitle
        case .privacy: return LegalDocuments.privacyTitle
        }
    }

    var updated: String {
        switch self {
        case .terms: return LegalDocuments.termsUpdated
        case .privacy: return LegalDocuments.privacyUpdated
        }
    }

    var sections: [LegalDocuments.Section] {
        switch self {
        case .terms: return LegalDocuments.termsSections
        case .privacy: return LegalDocuments.privacySections
        }
    }
}

// MARK: - Full-document reader (sheet)

/// Renders a bundled legal document in the app's editorial style. Presented
/// as a sheet from the auth step, the acceptance gate, and Settings.
struct LegalDocView: View {
    let doc: LegalDoc

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(doc.title)
                            .font(.coDisplay(24, weight: .semibold))
                            .foregroundColor(.coInk)
                        Text(doc.updated)
                            .font(.coUI(12))
                            .foregroundColor(.coInkTertiary)
                    }
                    .padding(.top, 8)

                    ForEach(doc.sections) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            if let heading = section.heading {
                                Text(heading)
                                    .font(.coUI(15, weight: .semibold))
                                    .foregroundColor(.coInk)
                            }
                            Text(section.body)
                                .font(.coUI(14))
                                .foregroundColor(.coInkSecondary)
                                .lineSpacing(5)
                        }
                    }

                    Spacer(minLength: 32)
                }
                .padding(.horizontal, 24)
            }
            .background(Color.coPaper.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(.coUI(15, weight: .medium))
                        .foregroundColor(.coInk)
                }
            }
        }
    }
}

// MARK: - Consent row (embedded in AuthSheet's create-account mode)

/// The agreement control shown before an account can be created: a checkbox,
/// plain-language commitment, and links to read the full documents.
struct LegalConsentRow: View {
    @Binding var agreed: Bool
    @Binding var presentedDoc: LegalDoc?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeOut(duration: 0.15)) { agreed.toggle() }
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    checkbox
                    Text("I agree to the Terms of Use & EULA and Privacy Policy, and I'll help keep this space free of objectionable or abusive content.")
                        .font(.coUI(13))
                        .foregroundColor(.coInkSecondary)
                        .lineSpacing(3)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            HStack(spacing: 18) {
                docLink("Read the Terms", doc: .terms)
                docLink("Privacy Policy", doc: .privacy)
            }
            .padding(.leading, 34)
        }
    }

    private var checkbox: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(agreed ? Color.coCrossRed : Color.coCard)
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(agreed ? Color.coCrossRed : Color.coDivider, lineWidth: 1.4)
            if agreed {
                CheckmarkShape()
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .frame(width: 11, height: 9)
            }
        }
        .frame(width: 22, height: 22)
        .padding(.top, 1)
    }

    private func docLink(_ label: String, doc: LegalDoc) -> some View {
        Button { presentedDoc = doc } label: {
            Text(label)
                .font(.coUI(12, weight: .medium))
                .foregroundColor(.coInk)
                .underline()
        }
        .buttonStyle(.plain)
    }
}

/// A plain check stroke for the consent checkbox.
private struct CheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.55))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.36, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return p
    }
}

// MARK: - Acceptance gate (existing accounts)

/// Full-screen, non-dismissible gate for signed-in users who haven't yet
/// accepted the current Terms version (accounts created before this flow
/// existed, or after a material Terms update). Warm and brief: a short
/// summary of what they're agreeing to, links to the full documents, and a
/// single agree action. Sign out is the only other way forward.
struct LegalAcceptanceGateView: View {
    @EnvironmentObject private var appState: AppState
    @State private var presentedDoc: LegalDoc?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 36)

            Text("One thing before\nwe continue.")
                .font(.coDisplay(28, weight: .semibold))
                .foregroundColor(.coInk)
                .fixedSize(horizontal: false, vertical: true)

            Text("We keep Crossed Out a safe, honest place. Before going on, please review and agree to our updated terms.")
                .font(.coUI(15))
                .foregroundColor(.coInkSecondary)
                .lineSpacing(4)
                .padding(.top, 10)

            COCard {
                VStack(alignment: .leading, spacing: 14) {
                    commitmentLine("Zero tolerance for objectionable or abusive content \u{2014} report and block are always one tap away, and reports are acted on within 24 hours.")
                    CODivider()
                    commitmentLine("Kyra and the App offer spiritual encouragement, not professional advice. In a crisis, call or text 988 (U.S.) or local emergency services.")
                    CODivider()
                    commitmentLine("Your reflections and check-ins are sensitive. They stay yours \u{2014} never sold, never used to train outside AI models.")
                }
            }
            .padding(.top, 22)

            HStack(spacing: 18) {
                Button { presentedDoc = .terms } label: {
                    linkLabel("Terms of Use & EULA")
                }
                .buttonStyle(.plain)
                Button { presentedDoc = .privacy } label: {
                    linkLabel("Privacy Policy")
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 16)

            Spacer()

            COPrimaryButton(title: "I Agree") {
                appState.acceptCurrentLegal()
            }
            COSecondaryButton(title: "Sign Out") {
                appState.signOutAndReset()
            }
            .padding(.bottom, 16)
        }
        .padding(.horizontal, 24)
        .background(Color.coPaper.ignoresSafeArea())
        .sheet(item: $presentedDoc) { LegalDocView(doc: $0) }
    }

    private func commitmentLine(_ text: String) -> some View {
        Text(text)
            .font(.coUI(13))
            .foregroundColor(.coInkSecondary)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func linkLabel(_ text: String) -> some View {
        Text(text)
            .font(.coUI(13, weight: .medium))
            .foregroundColor(.coInk)
            .underline()
    }
}

#Preview("Doc") {
    LegalDocView(doc: .terms)
}

#Preview("Gate") {
    LegalAcceptanceGateView()
        .environmentObject(AppState())
}
