import SwiftUI

/// Compose a new "independent study" devotional: the verse the user studied,
/// an optional title, and their own notes/takeaways.
struct IndependentStudyComposerView: View {
    var onSaved: (UserDevotional) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var verseRef = ""
    @State private var notes = ""
    @State private var saving = false

    private var canSave: Bool {
        !verseRef.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !saving
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    field(label: "VERSE", required: true) {
                        TextField("e.g. Romans 8:28", text: $verseRef)
                            .font(.coUI(16))
                            .textInputAutocapitalization(.words)
                    }
                    field(label: "TITLE (OPTIONAL)", required: false) {
                        TextField("What was this study about?", text: $title)
                            .font(.coUI(16))
                    }
                    field(label: "YOUR NOTES", required: true) {
                        ZStack(alignment: .topLeading) {
                            if notes.isEmpty {
                                Text("What stood out? What is God showing you?")
                                    .font(.coScripture(16))
                                    .foregroundColor(.coInkTertiary)
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                            }
                            TextEditor(text: $notes)
                                .font(.coScripture(16))
                                .frame(minHeight: 160)
                                .scrollContentBackground(.hidden)
                        }
                    }

                    COPrimaryButton(title: saving ? "Saving…" : "Save Devotional") {
                        save()
                    }
                    .opacity(canSave ? 1 : 0.5)
                    .disabled(!canSave)
                    .padding(.top, 4)
                }
                .padding(22)
            }
            .background(Color.coPaper.ignoresSafeArea())
            .navigationTitle("Independent Study")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.coInkSecondary)
                }
            }
        }
    }

    @ViewBuilder
    private func field<Content: View>(label: String, required: Bool,
                                      @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.coUI(11, weight: .medium))
                .tracking(1.2)
                .foregroundColor(.coInkTertiary)
            content()
                .padding(12)
                .background(Color.coCard)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.coDivider, lineWidth: 1)
                )
        }
    }

    private func save() {
        guard canSave else { return }
        saving = true
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            let saved = await SupabaseService.shared.createUserDevotional(
                title: t.isEmpty ? nil : t,
                verseRef: verseRef.trimmingCharacters(in: .whitespacesAndNewlines),
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines))
            saving = false
            if let saved {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                onSaved(saved)
                dismiss()
            }
        }
    }
}
