import SwiftUI
import UIKit

// MARK: - Situations (deterministic templates first; Kyra assist is the
// gated, capped upgrade)

/// The situations a Bridge is usually built for. Each carries pre-written,
/// non-manipulative template copy the sender can pick and edit freely —
/// zero AI. "Ask Kyra to word it" is the optional, explicitly-tapped,
/// daily-capped AI path (same kyra_usage cap as chat).
enum BridgeSituation: String, CaseIterable, Identifiable {
    case grief = "Grief"
    case breakup = "A breakup"
    case stress = "Stress"
    case curiosity = "Curious about faith"
    case loneliness = "Loneliness"
    case hurtByChurch = "Hurt by Christianity"
    case nervousAboutChurch = "Nervous about church"

    var id: String { rawValue }

    /// For the Kyra prompt: "my friend, who is …"
    var promptClause: String {
        switch self {
        case .grief: return "grieving a loss"
        case .breakup: return "going through a breakup"
        case .stress: return "under heavy stress"
        case .curiosity: return "curious about faith but not a believer"
        case .loneliness: return "feeling deeply lonely"
        case .hurtByChurch: return "angry at Christianity because church people have hurt them"
        case .nervousAboutChurch: return "interested in church but nervous and intimidated by it"
        }
    }

    var whyTemplate: String {
        switch self {
        case .grief: return "I've been thinking about you a lot since your loss."
        case .breakup: return "You've been on my mind since the breakup."
        case .stress: return "I know how much pressure you've been under lately."
        case .curiosity: return "You asked some questions the other day that stuck with me."
        case .loneliness: return "I've had a feeling things might be lonelier than you let on."
        case .hurtByChurch: return "I know church people have hurt you, and I don't blame you for how you feel."
        case .nervousAboutChurch: return "You mentioned church feels intimidating, and I get that."
        }
    }

    var messageTemplate: String {
        switch self {
        case .grief:
            return "I don't have the right words, and I won't pretend to. I just want you to know you're not carrying this alone — I'm here, whenever and however you need."
        case .breakup:
            return "I know things have been heavy lately. No advice from me — just wanted you to know I'm in your corner, and I'm around if you ever want to talk, or just not be alone."
        case .stress:
            return "You've been juggling more than anyone should have to. I'm proud of you, and I'm here — even if it's just coffee and not talking about any of it."
        case .curiosity:
            return "I loved the questions you were asking. No agenda here — I just found something that's meant a lot to me and thought of you. Take it or leave it, honestly."
        case .loneliness:
            return "Just wanted to say: you matter to me, more than our schedules probably show. Can we fix that soon? Either way, this made me think of you today."
        case .hurtByChurch:
            return "You've got every right to be angry — some of what was done in God's name was genuinely wrong, and I'm not here to defend any of it. I just came across something gentler than what you were shown, and you deserved to see it."
        case .nervousAboutChurch:
            return "For what it's worth — nobody checks your ID at the door, and you can sit in the back with me. Zero pressure. I just didn't want awkwardness to be the only reason you never got to see it."
        }
    }

    /// Seed text shown in the verse picker search field.
    var verseSearchSeed: String { rawValue }

    /// Semantic query tuned for pastoral tone (welcome/comfort, not fear).
    var semanticSearchQuery: String {
        switch self {
        case .grief:
            return "comfort for someone grieving a loss; God near the brokenhearted; hope that does not minimize pain"
        case .breakup:
            return "healing after heartbreak; God's nearness when a relationship ends; peace and new mercies"
        case .stress:
            return "rest for the weary and anxious; cast your cares; peace that guards the heart under pressure"
        case .curiosity:
            return "gentle invitation to know God; seek and you will find; kindness that leads toward faith"
        case .loneliness:
            return "God's presence in loneliness; you are not forsaken; belonging and companionship"
        case .hurtByChurch:
            return "healing after church hurt or religious harm; Jesus gentle and lowly; rest for the wounded, not defense of hypocrisy"
        case .nervousAboutChurch:
            return "gentle welcome and belonging for someone nervous or intimidated about visiting church; God's kindness and open door, not fear or judgment"
        }
    }

    /// Hand-picked starter refs resolved from the live BSB corpus in the picker.
    var curatedVerseRefs: [(book: String, chapter: Int, verse: Int)] {
        switch self {
        case .grief:
            return [
                ("Psalms", 34, 18),
                ("Matthew", 5, 4),
                ("Revelation", 21, 4),
                ("2 Corinthians", 1, 3)
            ]
        case .breakup:
            return [
                ("Psalms", 147, 3),
                ("Isaiah", 41, 10),
                ("Psalms", 30, 5),
                ("Romans", 8, 38)
            ]
        case .stress:
            return [
                ("Matthew", 11, 28),
                ("Philippians", 4, 6),
                ("1 Peter", 5, 7),
                ("Psalms", 46, 1)
            ]
        case .curiosity:
            return [
                ("Matthew", 7, 7),
                ("Jeremiah", 29, 13),
                ("John", 1, 39),
                ("Acts", 17, 27)
            ]
        case .loneliness:
            return [
                ("Deuteronomy", 31, 6),
                ("Psalms", 23, 4),
                ("Isaiah", 43, 2),
                ("Hebrews", 13, 5)
            ]
        case .hurtByChurch:
            return [
                ("Matthew", 11, 28),
                ("Matthew", 23, 4),
                ("Psalms", 34, 18),
                ("John", 8, 7)
            ]
        case .nervousAboutChurch:
            return [
                ("Romans", 15, 7),
                ("Matthew", 11, 28),
                ("Hebrews", 10, 24),
                ("John", 14, 27)
            ]
        }
    }
}

// MARK: - Composer

/// Three-step Bridge builder: (1) who it's for + why + personal message,
/// (2) a real verse + what it means to me, (3) invitation, response
/// emphasis, preview, send → shareable link. Deterministic templates by
/// default; Kyra assist is optional, explicit, and capped.
struct BridgeComposerView: View {
    var onSent: () async -> Void = {}

    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    private enum Step: Int, CaseIterable { case who = 1, verse = 2, send = 3 }
    @State private var step: Step = .who

    // Step 1
    @State private var toName = ""
    @State private var situation: BridgeSituation?
    @State private var whyText = ""
    @State private var message = ""
    @State private var kyraDrafting = false
    @State private var kyraNote: String?

    // Step 2
    @State private var verseSelection: BridgeVersePicker.Selection?
    @State private var showVersePicker = false
    @State private var meaning = ""

    // Step 3
    @State private var invitation = ""
    @State private var responseOption = "any"
    @State private var sending = false
    @State private var sendFailed = false
    @State private var sentToken: String?

    private let responseOptions: [(value: String, label: String)] = [
        ("any", "Leave it open"),
        ("reply", "A private reply"),
        ("prayer", "Let me pray for you"),
        ("journey", "Walk a 7-day journey")
    ]

    var body: some View {
        Group {
            if let token = sentToken {
                sentView(token: token)
            } else {
                composer
            }
        }
        .background(Color.coPaper.ignoresSafeArea())
        .navigationTitle("Cross the Bridge")
        .navigationBarTitleDisplayMode(.inline)
        .hidesTabBar()
        .sheet(isPresented: $showVersePicker) {
            BridgeVersePicker(situation: situation) { selection in
                withAnimation { verseSelection = selection }
            }
            .environmentObject(appState)
        }
    }

    private var composer: some View {
        VStack(spacing: 0) {
            stepHeader
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch step {
                    case .who: whoStep
                    case .verse: verseStep
                    case .send: sendStep
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            footerButtons
        }
    }

    private var stepHeader: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                ForEach(Step.allCases, id: \.rawValue) { s in
                    Capsule()
                        .fill(s.rawValue <= step.rawValue ? Color.coCrossRed : Color.coDivider)
                        .frame(height: 3)
                }
            }
            Text(stepTitle)
                .font(.coUI(12, weight: .medium))
                .tracking(1.2)
                .foregroundColor(.coInkTertiary)
        }
        .padding(.horizontal, 22)
        .padding(.top, 10)
    }

    private var stepTitle: String {
        switch step {
        case .who: return "STEP 1 · WHO IT'S FOR"
        case .verse: return "STEP 2 · THE SCRIPTURE"
        case .send: return "STEP 3 · SEND IT"
        }
    }

    private var canAdvance: Bool {
        switch step {
        case .who:
            return !toName.trimmingCharacters(in: .whitespaces).isEmpty
                && !whyText.trimmingCharacters(in: .whitespaces).isEmpty
                && !message.trimmingCharacters(in: .whitespaces).isEmpty
        case .verse:
            return verseSelection != nil
                && !meaning.trimmingCharacters(in: .whitespaces).isEmpty
        case .send:
            return !sending
        }
    }

    private var footerButtons: some View {
        VStack(spacing: 6) {
            CODivider()
            HStack(spacing: 12) {
                if step != .who {
                    COSecondaryButton(title: "Back") {
                        withAnimation(.easeOut(duration: 0.2)) {
                            step = Step(rawValue: step.rawValue - 1) ?? .who
                        }
                    }
                    .frame(width: 90)
                }
                COPrimaryButton(title: step == .send ? (sending ? "Sending…" : "Send the Bridge") : "Continue") {
                    advance()
                }
                .opacity(canAdvance ? 1 : 0.5)
                .disabled(!canAdvance)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 10)
        }
        .background(Color.coPaper)
    }

    private func advance() {
        switch step {
        case .who:
            withAnimation(.easeOut(duration: 0.2)) { step = .verse }
        case .verse:
            withAnimation(.easeOut(duration: 0.2)) { step = .send }
        case .send:
            send()
        }
    }

    // MARK: Step 1 — who & why

    private var whoStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            fieldBlock("Who is this for?") {
                styledField("Their first name", text: $toName)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("What are they walking through?")
                    .font(.coUI(13, weight: .medium))
                    .foregroundColor(.coInkTertiary)
                COFlowLayout(hSpacing: 10, vSpacing: 10) {
                    ForEach(BridgeSituation.allCases) { s in
                        COChip(text: s.rawValue, selected: situation == s) {
                            selectSituation(s)
                        }
                    }
                }
                Text("Picking one fills in a starting point you can edit — or skip it and write your own.")
                    .font(.coUI(11))
                    .foregroundColor(.coInkTertiary)
            }

            fieldBlock("Why I thought of you") {
                styledEditor($whyText, placeholder: "One honest sentence about why they came to mind.", minHeight: 60)
            }

            fieldBlock("Your message") {
                styledEditor($message, placeholder: "Plain and human. No pressure, no preachiness.", minHeight: 110)
            }

            kyraAssist
        }
    }

    private func selectSituation(_ s: BridgeSituation) {
        withAnimation(.easeOut(duration: 0.2)) {
            situation = s
            whyText = s.whyTemplate
            message = s.messageTemplate
        }
    }

    /// The only AI in this feature: explicit tap, runs through the existing
    /// Kyra edge function and its per-user daily cap (kyra_usage). The
    /// deterministic templates above are the default path.
    private var kyraAssist: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                draftWithKyra()
            } label: {
                HStack(spacing: 6) {
                    COIcon(.prayer, size: 14, color: .coOlive)
                    Text(kyraDrafting ? "Kyra is writing…" : "Ask Kyra to help word this")
                        .font(.coUI(13, weight: .medium))
                        .foregroundColor(.coOlive)
                }
            }
            .buttonStyle(.plain)
            .disabled(kyraDrafting || situation == nil)
            .opacity(situation == nil ? 0.5 : 1)

            if situation == nil {
                Text("Pick a situation above first so Kyra knows the context.")
                    .font(.coUI(11))
                    .foregroundColor(.coInkTertiary)
            }
            if let kyraNote {
                Text(kyraNote)
                    .font(.coUI(12))
                    .foregroundColor(.coInkTertiary)
            }
        }
    }

    private func draftWithKyra() {
        guard let situation, !kyraDrafting else { return }
        kyraDrafting = true
        kyraNote = nil
        let name = toName.trimmingCharacters(in: .whitespaces)
        let prompt = """
        I'm writing a short personal note to my friend \(name.isEmpty ? "(no name yet)" : name), who is \(situation.promptClause). \
        Write a warm, honest, 2-4 sentence message from me to them. It must be compassionate and completely non-manipulative: \
        no pressure, no preachiness, no guilt, and no assumptions about what they believe. Don't quote Scripture or mention \
        the Bible — a verse travels separately. Write in my voice, plain and human. Return ONLY the message text, nothing else.
        """
        Task {
            do {
                let text = try await SupabaseService.shared.askKyra(
                    messages: [ChatMessage(role: .user, text: prompt)],
                    firstName: appState.profile.firstName
                )
                withAnimation { message = text.trimmingCharacters(in: .whitespacesAndNewlines) }
            } catch KyraServiceError.dailyLimitReached {
                kyraNote = "You've reached today's Kyra limit — the templates still work, and your own words are best anyway."
            } catch {
                kyraNote = "Kyra couldn't help just now. Try a template or your own words."
            }
            kyraDrafting = false
        }
    }

    // MARK: Step 2 — the Scripture

    private var verseStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            fieldBlock("The verse") {
                Button {
                    showVersePicker = true
                } label: {
                    COCard {
                        if let v = verseSelection {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(v.ref)
                                        .font(.coUI(13, weight: .semibold))
                                        .foregroundColor(.coCrossRed)
                                    Spacer()
                                    Text("Change")
                                        .font(.coUI(12, weight: .medium))
                                        .foregroundColor(.coOlive)
                                }
                                Text(v.text)
                                    .font(.coScripture(17))
                                    .foregroundColor(.coInk)
                                    .lineSpacing(6)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        } else {
                            HStack {
                                COIcon(.bible, size: 18, color: .coInkSecondary)
                                Text("Choose a verse")
                                    .font(.coUI(15, weight: .medium))
                                    .foregroundColor(.coInk)
                                Spacer()
                                COIcon(.chevronRight, size: 14, color: .coInkTertiary)
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
            }

            fieldBlock("What it means to me") {
                styledEditor($meaning, placeholder: "A sentence or two about what this verse has meant in your own life.", minHeight: 90)
            }
        }
    }

    // MARK: Step 3 — send

    private var sendStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            fieldBlock("An invitation (optional)") {
                styledEditor($invitation, placeholder: "e.g. \u{201C}Sunday, 10am — I'll save you a seat. Only if you want.\u{201D}", minHeight: 56)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("What would you love back? (They'll never be pressured.)")
                    .font(.coUI(13, weight: .medium))
                    .foregroundColor(.coInkTertiary)
                COFlowLayout(hSpacing: 10, vSpacing: 10) {
                    ForEach(responseOptions, id: \.value) { option in
                        COChip(text: option.label, selected: responseOption == option.value) {
                            responseOption = option.value
                        }
                    }
                }
            }

            previewCard

            if sendFailed {
                Text("Couldn't send right now. Check your connection and try again.")
                    .font(.coUI(13))
                    .foregroundColor(.coCrossRed)
            }

            Text("They open a simple web page — no app, no account, nothing collected from them. They can respond, or quietly not. Both are okay.")
                .font(.coUI(12))
                .foregroundColor(.coInkTertiary)
                .lineSpacing(3)
        }
    }

    private var previewCard: some View {
        COCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("PREVIEW")
                    .font(.coUI(10, weight: .semibold))
                    .tracking(1.4)
                    .foregroundColor(.coInkTertiary)
                Text("For \(toName.trimmingCharacters(in: .whitespaces))")
                    .font(.coDisplay(18, weight: .semibold))
                    .foregroundColor(.coInk)
                Text(whyText)
                    .font(.coUIItalic(13))
                    .foregroundColor(.coInkSecondary)
                Text(message)
                    .font(.coUI(14))
                    .foregroundColor(.coInk)
                    .lineSpacing(4)
                if let v = verseSelection {
                    HStack(alignment: .top, spacing: 10) {
                        RoundedRectangle(cornerRadius: 1.5).fill(Color.coGold).frame(width: 3)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(v.text)
                                .font(.coScripture(15, italic: true))
                                .foregroundColor(.coInk)
                                .lineSpacing(5)
                            Text("— \(v.ref) (BSB)")
                                .font(.coUI(11))
                                .foregroundColor(.coInkTertiary)
                        }
                    }
                }
                Text(meaning)
                    .font(.coUI(13))
                    .foregroundColor(.coInkSecondary)
                    .lineSpacing(4)
            }
        }
    }

    private func send() {
        guard let v = verseSelection, !sending else { return }
        sending = true
        sendFailed = false
        Task {
            do {
                let token = try await SupabaseService.shared.createBridge(
                    senderName: appState.profile.firstName,
                    toName: toName.trimmingCharacters(in: .whitespaces),
                    whyText: whyText.trimmingCharacters(in: .whitespacesAndNewlines),
                    message: message.trimmingCharacters(in: .whitespacesAndNewlines),
                    verseRef: v.ref,
                    verseText: v.text,
                    verseBook: v.book,
                    verseChapter: v.chapter,
                    verseStart: v.verse,
                    verseEnd: nil,
                    meaning: meaning.trimmingCharacters(in: .whitespacesAndNewlines),
                    invitation: invitation.trimmingCharacters(in: .whitespacesAndNewlines),
                    responseOption: responseOption
                )
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                withAnimation(.easeOut(duration: 0.3)) { sentToken = token }
                await onSent()
            } catch {
                sendFailed = true
            }
            sending = false
        }
    }

    // MARK: Sent!

    private func sentView(token: String) -> some View {
        let link = BridgeConfig.link(token: token)
        return VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ZStack {
                        BridgeMotif(width: 140)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 24)

                    Text("Your bridge is built.")
                        .font(.coDisplay(26, weight: .semibold))
                        .foregroundColor(.coInk)
                        .frame(maxWidth: .infinity, alignment: .center)

                    Text("Send \(toName) the link however you normally talk — text, DM, whatever feels natural. They won't need an app or an account.")
                        .font(.coUI(14))
                        .foregroundColor(.coInkSecondary)
                        .lineSpacing(4)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)

                    COCard {
                        Text(link)
                            .font(.coUI(12))
                            .foregroundColor(.coInk)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    HStack(spacing: 14) {
                        Button {
                            UIPasteboard.general.string = link
                            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        } label: {
                            Label("Copy link", systemImage: "doc.on.doc")
                                .font(.coUI(14, weight: .medium))
                                .foregroundColor(.coInk)
                        }
                        .buttonStyle(.plain)
                        ShareLink(item: URL(string: link) ?? URL(string: BridgeConfig.baseURL)!,
                                  message: Text(shareMessage)) {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .font(.coUI(14, weight: .medium))
                                .foregroundColor(.coInk)
                        }
                        Spacer()
                    }

                    Text("You'll see it in Your Bridges — including when it's opened and anything they send back.")
                        .font(.coUI(12))
                        .foregroundColor(.coInkTertiary)
                        .lineSpacing(3)
                }
                .padding(.horizontal, 22)
            }
            CODivider()
            COPrimaryButton(title: "Done") { dismiss() }
                .padding(.horizontal, 22)
                .padding(.vertical, 10)
        }
    }

    private var shareMessage: String {
        "Thought of you today — no pressure at all, just something I wanted you to have."
    }

    // MARK: Field helpers

    private func fieldBlock<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.coUI(13, weight: .medium))
                .foregroundColor(.coInkTertiary)
            content()
        }
    }

    private func styledField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .font(.coUI(15))
            .foregroundColor(.coInk)
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()
            .padding(12)
            .background(Color.coCard)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.coDivider, lineWidth: 1)
            )
    }

    private func styledEditor(_ text: Binding<String>, placeholder: String, minHeight: CGFloat) -> some View {
        TextField(placeholder, text: text, axis: .vertical)
            .font(.coUI(14))
            .foregroundColor(.coInk)
            .lineLimit(2...10)
            .padding(12)
            .frame(minHeight: minHeight, alignment: .top)
            .background(Color.coCard)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.coDivider, lineWidth: 1)
            )
    }
}
