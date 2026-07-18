import SwiftUI

/// Tier 3 (G19 §9): the explicit, gated AI escape hatch. The user describes
/// what they're carrying; we retrieve a real verse + a short framed
/// reflection via the devotional_suggest edge function (per-user daily cap).
/// They can save it to their studies. The deterministic paths remain default.
struct AiSuggestionSheet: View {
    var onSaved: (UserDevotional) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var context = ""
    @State private var loading = false
    @State private var saving = false
    @State private var result: AiDevotionalSuggestion?
    @State private var errorText: String?

    private var canAsk: Bool {
        !context.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !loading
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Tell me what you're carrying, and I'll find a verse and a short reflection for it.")
                        .font(.coUI(14))
                        .foregroundColor(.coInkSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    ZStack(alignment: .topLeading) {
                        if context.isEmpty {
                            Text("e.g. I'm anxious about a decision at work…")
                                .font(.coScripture(16))
                                .foregroundColor(.coInkTertiary)
                                .padding(.top, 8).padding(.leading, 5)
                        }
                        TextEditor(text: $context)
                            .font(.coScripture(16))
                            .frame(minHeight: 110)
                            .scrollContentBackground(.hidden)
                    }
                    .padding(12)
                    .background(Color.coCard)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.coDivider, lineWidth: 1))

                    COPrimaryButton(title: loading ? "Finding a verse…" : "Get a suggestion") { ask() }
                        .opacity(canAsk ? 1 : 0.5)
                        .disabled(!canAsk)

                    if let errorText {
                        Text(errorText)
                            .font(.coUI(13))
                            .foregroundColor(.coCrossRed)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let result { resultCard(result) }
                }
                .padding(22)
            }
            .background(Color.coPaper.ignoresSafeArea())
            .navigationTitle("AI Suggestion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }.foregroundColor(.coInkSecondary)
                }
            }
        }
    }

    private func resultCard(_ s: AiDevotionalSuggestion) -> some View {
        COCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(s.verseRef.uppercased())
                    .font(.coUI(11, weight: .medium)).tracking(1.3).foregroundColor(.coCrossRed)
                Text("\u{201C}\(s.text)\u{201D}")
                    .font(.coScripture(16, italic: true)).foregroundColor(.coInk)
                    .fixedSize(horizontal: false, vertical: true)
                Text(s.title)
                    .font(.coUI(15, weight: .semibold)).foregroundColor(.coInk)
                Text(s.body)
                    .font(.coScripture(15)).foregroundColor(.coInkSecondary).lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
                if let p = s.prompt, !p.isEmpty {
                    Text(p)
                        .font(.coScripture(14, italic: true)).foregroundColor(.coInkTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text("AI-suggested, grounded in the verse above.")
                    .font(.coUI(11)).foregroundColor(.coInkTertiary)
                COPrimaryButton(title: saving ? "Saving…" : "Save to my studies") { save(s) }
                    .disabled(saving)
                    .padding(.top, 2)
                Button("Try another") { withAnimation { result = nil } }
                    .font(.coUI(14, weight: .medium))
                    .foregroundColor(.coInkSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func ask() {
        guard canAsk else { return }
        loading = true; errorText = nil; result = nil
        let ctx = context.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            let outcome = await SupabaseService.shared.requestAiDevotionalSuggestion(context: ctx)
            loading = false
            switch outcome {
            case .success(let s):
                withAnimation { result = s }
            case .failure(.dailyLimit):
                errorText = "You've reached today's AI-suggestion limit — the daily verse and devotional are always here."
            case .failure(.notSignedIn):
                errorText = "Please sign in to use AI suggestions."
            case .failure(.failed):
                errorText = "Couldn't get a suggestion right now. Please try again."
            }
        }
    }

    private func save(_ s: AiDevotionalSuggestion) {
        guard !saving else { return }
        saving = true
        var notes = s.body
        if let p = s.prompt, !p.isEmpty { notes += "\n\nReflect: \(p)" }
        Task {
            let saved = await SupabaseService.shared.createUserDevotional(
                title: s.title, verseRef: s.verseRef,
                book: s.book, chapter: s.chapter, verse: s.verse, verseEnd: nil,
                notes: notes)
            saving = false
            if let saved {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                onSaved(saved); dismiss()
            }
        }
    }
}
