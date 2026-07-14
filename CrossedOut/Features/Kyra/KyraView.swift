import SwiftUI

// MARK: - Kyra

struct KyraView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    @State private var messages: [ChatMessage] = Array(MockData.kyraConversation.prefix(2))
    @State private var input: String = ""
    @State private var isReflecting = false
    @State private var suggestionUsed = false

    var body: some View {
        VStack(spacing: 0) {
            header
            conversation
            inputBar
        }
        .background(Color.coPaper.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
    }

    // MARK: Header

    private var header: some View {
        ZStack {
            HStack {
                Button { dismiss() } label: {
                    COIcon(.chevronRight, size: 20, color: .coInkSecondary)
                        .rotationEffect(.degrees(180))
                }
                .buttonStyle(.plain)
                Spacer()
            }
            VStack(spacing: 6) {
                Text("K")
                    .font(.coScripture(22))
                    .foregroundColor(.coInk)
                    .frame(width: 36, height: 36)
                    .overlay(Circle().strokeBorder(Color.coDivider, lineWidth: 1))
                Text("Talk with Kyra")
                    .font(.coUI(15, weight: .semibold))
                    .foregroundColor(.coInk)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) { CODivider() }
    }

    // MARK: Conversation

    private var conversation: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(messages) { msg in
                        KyraBubble(message: msg)
                            .id(msg.id)
                            .transition(.opacity.combined(with: .offset(y: 4)))
                    }
                    if isReflecting {
                        Text("Kyra is reflecting…")
                            .font(.coUIItalic(13))
                            .foregroundColor(.coInkTertiary)
                            .padding(.leading, 40)
                            .id("reflecting")
                    }
                    if showSuggestion {
                        suggestionCapsule
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
            }
            .onChange(of: messages.count) { _, _ in
                withAnimation { proxy.scrollTo(messages.last?.id, anchor: .bottom) }
            }
        }
    }

    private var showSuggestion: Bool {
        !suggestionUsed && !isReflecting && messages.last?.role == .kyra
    }

    private var suggestionCapsule: some View {
        HStack {
            Spacer()
            Button { sendSuggestion() } label: {
                Text("Yes, please.")
                    .font(.coUI(13))
                    .foregroundColor(.coInkSecondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .overlay(Capsule().strokeBorder(Color.coDivider, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .transition(.opacity)
    }

    // MARK: Input Bar

    private var inputBar: some View {
        VStack(spacing: 0) {
            CODivider()
            HStack(spacing: 12) {
                HStack(spacing: 10) {
                    TextField("Ask Kyra anything...", text: $input, axis: .vertical)
                        .font(.coUI(14))
                        .foregroundColor(.coInk)
                        .lineLimit(1...4)
                    Button { } label: {
                        MicIcon(size: 18, color: .coInkTertiary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .overlay(Capsule().strokeBorder(Color.coDivider, lineWidth: 1))
                sendButton
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(Color.coPaper)
    }

    private var sendButton: some View {
        let empty = input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return Button { sendInput() } label: {
            COIcon(.chevronRight, size: 20, color: empty ? .coInkTertiary : .coCrossRed)
                .frame(width: 40, height: 40)
                .overlay(Circle().strokeBorder(
                    empty ? Color.coDivider : Color.coCrossRed, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(empty)
    }

    // MARK: Actions

    private func sendSuggestion() {
        withAnimation(.easeOut(duration: 0.25)) {
            suggestionUsed = true
            messages.append(ChatMessage(role: .user, text: "Yes, please."))
        }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        reflectThen([
            ChatMessage(role: .kyra, text: "Father, thank You that Tyler doesn't have to carry the weight of the future alone. Give him wisdom with money, peace in uncertainty, and trust that You are preparing something good. Amen."),
            ChatMessage(role: .kyra, text: "I'm here whenever you want to reflect again.")
        ])
    }

    private func sendInput() {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        withAnimation(.easeOut(duration: 0.25)) {
            messages.append(ChatMessage(role: .user, text: trimmed))
        }
        input = ""
        askKyraThen(fallback: [
            ChatMessage(role: .kyra, text: "That's worth sitting with. Many Christians find that bringing this honestly to God in prayer is the best first step. Would you like a verse that speaks to it?")
        ])
    }

    /// Tries the live Kyra edge function first; on ANY failure (not deployed
    /// yet, network error, bad response, etc.) falls back to the canned
    /// reply silently and instantly — the user should never see an error.
    private func askKyraThen(fallback: [ChatMessage]) {
        withAnimation(.easeOut(duration: 0.25)) { isReflecting = true }
        let history = messages
        let firstName = appState.profile.firstName
        Task {
            var replies = fallback
            if let text = try? await SupabaseService.shared.askKyra(messages: history, firstName: firstName) {
                replies = [ChatMessage(role: .kyra, text: text)]
            }
            withAnimation(.easeOut(duration: 0.3)) {
                isReflecting = false
                messages.append(contentsOf: replies)
            }
        }
    }

    private func reflectThen(_ replies: [ChatMessage]) {
        withAnimation(.easeOut(duration: 0.25)) { isReflecting = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeOut(duration: 0.3)) {
                isReflecting = false
                messages.append(contentsOf: replies)
            }
        }
    }
}

// MARK: - Message Bubble

private struct KyraBubble: View {
    let message: ChatMessage

    var body: some View {
        if message.role == .kyra {
            HStack(alignment: .top, spacing: 10) {
                COAvatar(initials: "K", size: 30)
                Text(message.text)
                    .font(.coUI(14.5))
                    .foregroundColor(.coInk)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.coCard))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.coDivider, lineWidth: 1))
                    .frame(maxWidth: 300, alignment: .leading)
                Spacer(minLength: 20)
            }
        } else {
            HStack {
                Spacer(minLength: 48)
                Text(message.text)
                    .font(.coUI(14))
                    .foregroundColor(.coInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.coPaperSecondary))
                    .frame(maxWidth: 280, alignment: .trailing)
            }
        }
    }
}

// MARK: - Mic Icon (monoline, matches COIcon feel)

private struct MicIcon: View {
    var size: CGFloat = 18
    var color: Color = .coInkTertiary

    var body: some View {
        MicShape()
            .stroke(color, style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
    }
}

private struct MicShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 24
        let ox = rect.minX + (rect.width - 24 * s) / 2
        let oy = rect.minY + (rect.height - 24 * s) / 2
        func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: ox + x * s, y: oy + y * s) }
        var p = Path()
        p.addRoundedRect(in: CGRect(x: P(9, 3).x, y: P(9, 3).y, width: 6 * s, height: 10 * s),
                         cornerSize: CGSize(width: 3 * s, height: 3 * s))
        p.move(to: P(6, 11)); p.addQuadCurve(to: P(18, 11), control: P(12, 20))
        p.move(to: P(12, 17)); p.addLine(to: P(12, 20))
        p.move(to: P(9, 20)); p.addLine(to: P(15, 20))
        return p
    }
}

// MARK: - Preview

#Preview {
    NavigationStack { KyraView() }
        .environmentObject(AppState())
}
