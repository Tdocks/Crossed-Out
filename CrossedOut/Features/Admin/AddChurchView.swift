import SwiftUI

/// System-admin screen to add a church by its YouTube channel. Calls the
/// add_church edge function, which resolves the channel, upserts the church,
/// and creates its live_services row so it appears in Attend right away. This
/// replaces having to run scripts/add_church.sh from a terminal.
struct AddChurchView: View {
    @State private var input = ""
    @State private var name = ""
    @State private var city = ""
    @State private var denomination = ""
    @State private var style = ""

    @State private var isSubmitting = false
    @State private var result: SupabaseService.AddChurchResult?
    @State private var errorMessage: String?

    private var canSubmit: Bool {
        !input.trimmingCharacters(in: .whitespaces).isEmpty && !isSubmitting
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Add a church")
                        .font(.coDisplay(28, weight: .semibold))
                        .foregroundColor(.coInk)
                    Text("Paste a YouTube channel and we'll resolve it, pull the thumbnail, and wire up live detection automatically.")
                        .font(.coUI(14))
                        .foregroundColor(.coInkSecondary)
                        .lineSpacing(3)
                }
                .padding(.top, 8)

                ChurchTextField(label: "YouTube channel", placeholder: "@handle, channel URL, or UC… ID", text: $input,
                                autocapitalization: .never, keyboard: .URL, autocorrect: false)
                Text("Leave the fields below blank to use the channel's own name.")
                    .font(.coUI(12))
                    .foregroundColor(.coInkTertiary)

                ChurchTextField(label: "Name (optional)", placeholder: "Overrides the channel name", text: $name)
                ChurchTextField(label: "City (optional)", placeholder: "e.g. Charlotte, NC", text: $city)
                ChurchTextField(label: "Denomination (optional)", placeholder: "e.g. Non-denominational", text: $denomination)
                ChurchTextField(label: "Service style (optional)", placeholder: "e.g. Contemporary", text: $style)

                if let result {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Added \(result.name)")
                            .font(.coUI(15, weight: .semibold))
                            .foregroundColor(.coOlive)
                        Text(result.liveNow ? "It's live right now — already showing in Attend." : "Saved. It'll appear live in Attend the next time it streams.")
                            .font(.coUI(13))
                            .foregroundColor(.coInkSecondary)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.coCard)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.coDivider, lineWidth: 1))
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.coUI(13))
                        .foregroundColor(.coCrossRed)
                }

                COPrimaryButton(title: isSubmitting ? "Adding…" : "Add church") { submit() }
                    .disabled(!canSubmit)
                    .opacity(canSubmit ? 1 : 0.5)
                    .padding(.top, 4)
                    .padding(.bottom, 32)
            }
            .padding(.horizontal, 24)
        }
        .background(Color.coPaper.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
    }

    private func submit() {
        errorMessage = nil
        result = nil
        isSubmitting = true
        Task {
            do {
                let r = try await SupabaseService.shared.addChurch(
                    input: input.trimmingCharacters(in: .whitespacesAndNewlines),
                    name: name, city: city, denomination: denomination, style: style
                )
                isSubmitting = false
                withAnimation {
                    result = r
                    // Clear the inputs so the next add starts fresh.
                    input = ""; name = ""; city = ""; denomination = ""; style = ""
                }
            } catch {
                isSubmitting = false
                withAnimation {
                    errorMessage = (error as? LocalizedError)?.errorDescription
                        ?? "Couldn't add that church. Try again."
                }
            }
        }
    }
}

#Preview {
    AddChurchView()
}
