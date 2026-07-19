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

// MARK: - Private reflection box (built-in devotional detail)

/// A save-able personal reflection tied to one built-in devotional.
/// One per user per devotional; editing updates it (upsert, migration 0028).
///
/// PRIVACY: this text is own-rows RLS data and is NEVER included in any
/// AI/edge-function payload. A future explicit opt-in could one day let
/// Kyra reference reflections (see `shared_with_kyra` in 0028) — that
/// remains OFF and unbuilt by design.
struct DevotionalReflectionBox: View {
    let devotionalID: UUID

    @State private var text = ""
    @State private var savedText = ""
    @State private var loading = true
    @State private var loadFailed = false
    @State private var saving = false
    @State private var saveFailed = false
    @State private var justSaved = false

    private var hasUnsavedChanges: Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed != savedText
    }

    var body: some View {
        COCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    COIcon(.note, size: 15, color: .coOlive)
                    Text("YOUR REFLECTION")
                        .font(.coUI(11, weight: .semibold))
                        .tracking(1.4)
                        .foregroundColor(.coInkTertiary)
                    Spacer()
                    if justSaved {
                        Text("Saved")
                            .font(.coUI(11, weight: .medium))
                            .foregroundColor(.coOlive)
                            .transition(.opacity)
                    }
                }

                if loading {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Loading your reflection…")
                            .font(.coUI(12))
                            .foregroundColor(.coInkTertiary)
                    }
                    .padding(.vertical, 6)
                } else {
                    TextEditor(text: $text)
                        .font(.coUI(14))
                        .foregroundColor(.coInk)
                        .lineSpacing(4)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 88)
                        .overlay(alignment: .topLeading) {
                            if text.isEmpty {
                                Text("What is God saying to you through this?")
                                    .font(.coUIItalic(14))
                                    .foregroundColor(.coInkTertiary)
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                                    .allowsHitTesting(false)
                            }
                        }

                    if loadFailed {
                        Text("Couldn't load a saved reflection — you can still write and save one.")
                            .font(.coUI(11))
                            .foregroundColor(.coInkTertiary)
                    }
                    if saveFailed {
                        Text("Couldn't save. Check your connection and try again.")
                            .font(.coUI(12))
                            .foregroundColor(.coCrossRed)
                    }

                    if hasUnsavedChanges {
                        Button {
                            save()
                        } label: {
                            Text(saving ? "Saving…" : "Save reflection")
                                .font(.coUI(13, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .frame(height: 38)
                                .background(Color.coCrossRed)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(saving)
                        .transition(.opacity)
                    }
                }

                CODivider().padding(.top, 2)
                Text("Private to you. Reflections are stored under row-level security so only your account can read them — never shared with other users, and never sent to Kyra or any AI.")
                    .font(.coUI(11))
                    .foregroundColor(.coInkTertiary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .animation(.easeOut(duration: 0.2), value: hasUnsavedChanges)
        .task { await load() }
    }

    private func load() async {
        do {
            if let existing = try await SupabaseService.shared.fetchMyReflection(devotionalID: devotionalID) {
                text = existing.body
                savedText = existing.body
            }
        } catch {
            loadFailed = true
        }
        loading = false
    }

    private func save() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !saving else { return }
        saving = true
        saveFailed = false
        Task {
            let ok = await SupabaseService.shared.saveReflection(devotionalID: devotionalID, body: trimmed)
            saving = false
            if ok {
                savedText = trimmed
                withAnimation(.easeOut(duration: 0.2)) { justSaved = true }
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation { justSaved = false }
                }
            } else {
                saveFailed = true
            }
        }
    }
}

// MARK: - Built-in devotional detail

struct DevotionalDetailView: View {
    let devotional: Devotional
    /// "Today's Devotional" from Today/hub; the archive passes "Devotional".
    var navTitle: String = "Today's Devotional"

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

                DevotionalReflectionBox(devotionalID: devotional.id)

                COCard {
                    HelpfulFeedbackControl(source: .builtin, devotionalID: devotional.id)
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 22)
            // Generous bottom inset so the last card (the helpful control)
            // scrolls fully clear of the home indicator / any floating
            // chrome and stays fully tappable.
            .padding(.bottom, 100)
        }
        .background(Color.coPaper.ignoresSafeArea())
        .navigationTitle(navTitle)
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
            .padding(.horizontal, 22)
            .padding(.top, 22)
            .padding(.bottom, 100)
        }
        .background(Color.coPaper.ignoresSafeArea())
        .navigationTitle("Devotional")
        .navigationBarTitleDisplayMode(.inline)
    }
}
