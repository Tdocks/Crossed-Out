import SwiftUI
import UIKit

// MARK: - Kyra

/// Kyra chat. The conversation is real and persistent (kyra_messages,
/// migration 0024): history loads on open, every turn is saved, and "New"
/// starts fresh by deleting the user's rows. Replies come only from the
/// hardened, retrieval-grounded edge function — there are no canned
/// responses. A deterministic on-device crisis detector surfaces real help
/// resources the moment a message suggests danger.
struct KyraView: View {
    var contextRef: String? = nil
    var contextText: String? = nil

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    @State private var messages: [ChatMessage] = []
    @State private var input: String = ""
    @State private var isReflecting = false
    @State private var isLoadingHistory = true
    @State private var historyLoaded = false
    @State private var hasSentContextPreamble = false
    @State private var crisisCategory: CrisisCategory?
    @State private var dailyLimitReached = false
    @State private var sendFailed = false
    @State private var showClearConfirm = false
    @State private var showPlusPaywall = false
    /// Ids of Kyra messages just reported, so the bubble can show a brief
    /// inline confirmation (mirrors CommunityView's justReportedIDs).
    @State private var justReportedMessageIDs: Set<UUID> = []
    /// Kyra's in-progress reply while tokens stream in. Non-nil from the
    /// first token until the stream completes (then the finished text moves
    /// into `messages`). Rendered as plain text mid-stream; the markdown
    /// treatment applies once complete.
    @State private var streamingText: String?
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            if let contextRef {
                contextChip(contextRef)
            }
            conversation
            inputBar
        }
        .background(Color.coPaper.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .hidesTabBar()
        .task { await loadHistoryIfNeeded() }
        .sheet(isPresented: $showPlusPaywall) {
            PlusPaywallView()
        }
        .confirmationDialog(
            "Start a fresh conversation? Your current one will be deleted.",
            isPresented: $showClearConfirm,
            titleVisibility: .visible
        ) {
            Button("Start Fresh", role: .destructive) { clearConversation() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func contextChip(_ ref: String) -> some View {
        Text("Reflecting on \(ref)")
            .font(.coUI(12))
            .foregroundColor(.coInkSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.coPaperSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, 20)
            .padding(.top, 10)
    }

    // MARK: Header

    private var header: some View {
        ZStack {
            HStack {
                Button {
                    appState.tabBarHidden = false   // belt-and-braces: never strand the user
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        COIcon(.chevronRight, size: 20, color: .coInkSecondary)
                            .rotationEffect(.degrees(180))
                        Text("Back")
                            .font(.coUI(14))
                            .foregroundColor(.coInkSecondary)
                    }
                    .padding(.vertical, 8)
                    .padding(.trailing, 12)
                    .contentShape(Rectangle())   // whole area tappable, not just the stroke
                }
                .buttonStyle(.plain)
                Spacer()
                if !messages.isEmpty {
                    Button {
                        showClearConfirm = true
                    } label: {
                        Text("New")
                            .font(.coUI(14))
                            .foregroundColor(.coInkSecondary)
                            .padding(.vertical, 8)
                            .padding(.leading, 12)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
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
                    if isLoadingHistory {
                        loadingState
                    } else if messages.isEmpty {
                        emptyState
                    }
                    ForEach(messages) { msg in
                        KyraBubble(
                            message: msg,
                            isReported: justReportedMessageIDs.contains(msg.id),
                            onReport: msg.role == .kyra ? { reportKyraMessage(msg) } : nil
                        )
                        .id(msg.id)
                        .transition(.opacity.combined(with: .offset(y: 4)))
                    }
                    if let crisisCategory {
                        CrisisResourcesCard(category: crisisCategory)
                            .id("crisis")
                            .transition(.opacity)
                    }
                    if let streamingText {
                        KyraLiveBubble(text: streamingText)
                            .id("streaming")
                            .transition(.opacity)
                    }
                    if isReflecting {
                        Text("Kyra is reflecting…")
                            .font(.coUIItalic(13))
                            .foregroundColor(.coInkTertiary)
                            .padding(.leading, 40)
                            .id("reflecting")
                    }
                    if sendFailed {
                        retryRow
                    }
                    if dailyLimitReached {
                        limitCard
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: messages.count) { _, _ in
                withAnimation { proxy.scrollTo(messages.last?.id, anchor: .bottom) }
            }
            .onChange(of: streamingText) { _, newValue in
                // Follow the live bubble as tokens arrive (no animation —
                // per-token animated scrolls stutter).
                if newValue != nil { proxy.scrollTo("streaming", anchor: .bottom) }
            }
            .onChange(of: crisisCategory != nil) { _, hasCrisis in
                if hasCrisis {
                    withAnimation { proxy.scrollTo("crisis", anchor: .bottom) }
                }
            }
        }
    }

    private var loadingState: some View {
        HStack(spacing: 10) {
            ProgressView()
            Text("Opening your conversation…")
                .font(.coUI(13))
                .foregroundColor(.coInkTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 32)
    }

    /// First-open (or freshly cleared) state: a warm welcome, honest
    /// disclaimer, and deterministic starter prompts that send through the
    /// real Kyra path.
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Hi\(appState.profile.firstName.isEmpty ? "" : ", \(appState.profile.firstName)"). I'm Kyra.")
                    .font(.coDisplay(22, weight: .semibold))
                    .foregroundColor(.coInk)
                Text("I'm here to help you understand Scripture, put words to prayer, and take small faithful steps. Whatever you're carrying, you can say it plainly.")
                    .font(.coUI(14))
                    .foregroundColor(.coInkSecondary)
                    .lineSpacing(5)
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(starterPrompts, id: \.self) { prompt in
                    Button {
                        send(prompt)
                    } label: {
                        Text(prompt)
                            .font(.coUI(13))
                            .foregroundColor(.coInk)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color.coCard)
                            .overlay(Capsule().strokeBorder(Color.coDivider, lineWidth: 1))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            Text("Kyra offers spiritual encouragement, not professional advice. In a crisis, call or text 988.")
                .font(.coUI(11))
                .foregroundColor(.coInkTertiary)
                .lineSpacing(3)
        }
        .padding(.top, 12)
    }

    private var starterPrompts: [String] {
        if let contextRef {
            return [
                "Help me understand \(contextRef) in my life right now",
                "Write a prayer from this verse for what I'm carrying",
                "What would living this verse out look like today?"
            ]
        }
        return [
            "Write a prayer for what I'm carrying today",
            "Help me understand a verse I've been reading",
            "I'm having a hard day"
        ]
    }

    private var retryRow: some View {
        HStack(spacing: 10) {
            Text("Kyra couldn't respond just now.")
                .font(.coUI(13))
                .foregroundColor(.coInkTertiary)
            Button {
                withAnimation { sendFailed = false }
                requestKyraReply()
            } label: {
                Text("Try again")
                    .font(.coUI(13, weight: .medium))
                    .foregroundColor(.coCrossRed)
                    .underline()
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 40)
        .transition(.opacity)
    }

    private var limitCard: some View {
        COCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("That's all for today.")
                    .font(.coUI(14, weight: .semibold))
                    .foregroundColor(.coInk)
                Text(
                    appState.isPlus
                    ? "You've reached today's Plus conversation limit with Kyra. She'll be here tomorrow. If something can't wait, reach out to a trusted friend, your church family, or a pastor."
                    : "You've reached today's free conversation limit with Kyra. Plus gives you more room today — or she'll be here tomorrow. If something can't wait, reach out to a trusted friend, your church family, or a pastor."
                )
                    .font(.coUI(13))
                    .foregroundColor(.coInkSecondary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                if !appState.isPlus {
                    COPrimaryButton(title: "See Crossed Out Plus") {
                        showPlusPaywall = true
                        AnalyticsService.shared.track("plus_paywall_from_kyra_limit")
                    }
                }
            }
        }
        .transition(.opacity)
    }

    // MARK: Input Bar

    private var inputBar: some View {
        VStack(spacing: 0) {
            CODivider()
            HStack(spacing: 12) {
                HStack(spacing: 10) {
                    TextField(dailyLimitReached ? "Kyra will be back tomorrow" : "Ask Kyra anything...",
                              text: $input, axis: .vertical)
                        .font(.coUI(14))
                        .foregroundColor(.coInk)
                        .lineLimit(1...4)
                        .focused($inputFocused)
                        .disabled(dailyLimitReached)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .overlay(Capsule().strokeBorder(Color.coDivider, lineWidth: 1))
                .contentShape(Rectangle())
                .onTapGesture { inputFocused = true }
                sendButton
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(Color.coPaper)
    }

    private var sendButton: some View {
        let empty = input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let blocked = empty || dailyLimitReached || isReflecting || streamingText != nil
        return Button { sendInput() } label: {
            COIcon(.chevronRight, size: 20, color: blocked ? .coInkTertiary : .coCrossRed)
                .frame(width: 40, height: 40)
                .overlay(Circle().strokeBorder(
                    blocked ? Color.coDivider : Color.coCrossRed, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(blocked)
    }

    // MARK: History

    private func loadHistoryIfNeeded() async {
        guard !historyLoaded else { return }
        historyLoaded = true
        defer { withAnimation(.easeOut(duration: 0.2)) { isLoadingHistory = false } }
        #if DEBUG
        // Screenshot/QA harness: seed a completed Kyra reply so the
        // "Report this response" affordance is reachable without a network
        // session (launched via CO_SEED=kyra). Never runs in release builds.
        if ProcessInfo.processInfo.environment["CO_SEED"]?.contains("kyra") == true {
            messages = [
                ChatMessage(role: .user, text: "I've been anxious about money lately."),
                ChatMessage(role: .kyra, text: "That weight is real, and you're not carrying it alone. In Philippians 4, Paul invites us to bring every worry to God in prayer — and promises a peace that guards the heart. Would it help to write a short prayer together, or look at what Scripture says about God's provision?")
            ]
            return
        }
        #endif
        if let history = try? await SupabaseService.shared.fetchKyraHistory() {
            messages = history
        }
        // On failure the conversation simply starts empty — chatting still
        // works, and history reappears next open once the network is back.
    }

    private func clearConversation() {
        Task {
            let cleared = await SupabaseService.shared.clearKyraHistory()
            guard cleared else { return }
            withAnimation(.easeOut(duration: 0.25)) {
                messages = []
                crisisCategory = nil
                dailyLimitReached = false
                sendFailed = false
                streamingText = nil
                hasSentContextPreamble = false
            }
        }
    }

    // MARK: Report

    /// Reports a completed Kyra reply via the shared content_reports pipeline
    /// (kind "kyra_message" — see migration 0043). `message.id` is the same
    /// UUID `saveKyraMessage` used as the kyra_messages row id, so it's a
    /// stable, already-persisted reference. `reportContent` is best-effort
    /// and never throws, so this can't crash the chat even if the insert
    /// fails server-side — the confirmation is optimistic, matching the
    /// community report affordance.
    private func reportKyraMessage(_ message: ChatMessage) {
        Task {
            await SupabaseService.shared.reportContent(
                kind: "kyra_message", contentID: message.id,
                reason: "Harmful or incorrect response", detail: nil
            )
        }
        withAnimation(.easeOut(duration: 0.2)) {
            _ = justReportedMessageIDs.insert(message.id)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation(.easeOut(duration: 0.3)) {
                _ = justReportedMessageIDs.remove(message.id)
            }
        }
    }

    // MARK: Actions

    private func sendInput() {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        input = ""
        inputFocused = true
        send(trimmed)
    }

    private func send(_ text: String) {
        guard !isReflecting, streamingText == nil, !dailyLimitReached else { return }
        let userMessage = ChatMessage(role: .user, text: text)
        withAnimation(.easeOut(duration: 0.25)) {
            messages.append(userMessage)
            sendFailed = false
        }
        Task { await SupabaseService.shared.saveKyraMessage(userMessage) }

        // Deterministic, on-device crisis check — real resources appear
        // immediately, before and regardless of the model's reply.
        if crisisCategory == nil, let category = CrisisDetector.detect(in: text) {
            withAnimation(.easeOut(duration: 0.25)) { crisisCategory = category }
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }

        requestKyraReply()
    }

    /// Calls the live, retrieval-grounded Kyra edge function and streams the
    /// reply token-by-token into a live bubble. No canned replies: failure
    /// shows an honest retry row, and the daily cap (returned as a 429
    /// before the stream ever starts) shows a gentle limit state. The full
    /// reply is persisted once the stream completes.
    private func requestKyraReply() {
        withAnimation(.easeOut(duration: 0.25)) { isReflecting = true }
        var history = messages
        if !hasSentContextPreamble, let contextRef, let contextText {
            // Slot the reading context in just before the latest user turn so
            // the edge function's rolling window (last 12) always keeps it.
            let preamble = ChatMessage(role: .user, text: "Context: I am reading \(contextRef): \"\(contextText)\"")
            history.insert(preamble, at: max(0, history.count - 1))
            hasSentContextPreamble = true
        }
        let firstName = appState.profile.firstName
        Task {
            do {
                let full = try await SupabaseService.shared.askKyraStreaming(
                    messages: history,
                    firstName: firstName
                ) { delta in
                    if streamingText == nil {
                        // First token: swap the "reflecting" indicator for
                        // the live bubble.
                        withAnimation(.easeOut(duration: 0.2)) {
                            isReflecting = false
                            streamingText = ""
                        }
                    }
                    streamingText = (streamingText ?? "") + delta
                }
                let reply = ChatMessage(role: .kyra, text: full)
                withAnimation(.easeOut(duration: 0.2)) {
                    isReflecting = false
                    streamingText = nil
                    messages.append(reply)
                }
                await SupabaseService.shared.saveKyraMessage(reply)
            } catch KyraServiceError.dailyLimitReached {
                withAnimation(.easeOut(duration: 0.3)) {
                    isReflecting = false
                    streamingText = nil
                    dailyLimitReached = true
                }
            } catch {
                withAnimation(.easeOut(duration: 0.3)) {
                    isReflecting = false
                    streamingText = nil
                    sendFailed = true
                }
            }
        }
    }
}

// MARK: - Message Bubble

private struct KyraBubble: View {
    let message: ChatMessage
    var isReported: Bool = false
    /// Non-nil only for Kyra's own replies — the user's own messages never
    /// get a report affordance. Nil while a reply is still streaming, since
    /// KyraBubble only ever renders completed, persisted messages.
    var onReport: (() -> Void)? = nil

    var body: some View {
        if message.role == .kyra {
            HStack(alignment: .top, spacing: 10) {
                COAvatar(initials: "K", size: 30)
                VStack(alignment: .leading, spacing: 6) {
                    // Completed Kyra messages get the markdown treatment:
                    // emphasis rendered, "> " lines as styled Scripture quotes,
                    // no leaked *, > or # characters.
                    KyraMessageBody(text: message.text)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.coCard))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.coDivider, lineWidth: 1))
                        .frame(maxWidth: 300, alignment: .leading)
                        .contextMenu {
                            if let onReport {
                                Button {
                                    onReport()
                                } label: {
                                    Label("Report this response", systemImage: "flag")
                                }
                            }
                        }
                    if isReported {
                        Text("Reported — thank you. We'll review this response.")
                            .font(.coUI(11))
                            .foregroundColor(.coInkTertiary)
                            .padding(.leading, 2)
                            .transition(.opacity)
                    }
                }
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

// MARK: - Live (streaming) Bubble

/// Kyra's in-progress reply. Rendered as plain text with a soft cursor while
/// tokens arrive — partial markdown mid-stream would flicker — then replaced
/// by the fully formatted KyraBubble when the stream completes.
private struct KyraLiveBubble: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            COAvatar(initials: "K", size: 30)
            (Text(text.isEmpty ? "" : text)
                + Text(text.isEmpty ? "▋" : " ▋")
                    .foregroundColor(.coCrossRed.opacity(0.55)))
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
    }
}

// MARK: - Preview

#Preview {
    NavigationStack { KyraView() }
        .environmentObject(AppState())
}
