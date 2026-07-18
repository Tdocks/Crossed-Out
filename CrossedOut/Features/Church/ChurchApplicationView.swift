import SwiftUI

/// In-app church self-signup form. Reached AFTER the rep has created an
/// account (so there is a session to attach the application to). On submit it
/// calls `submit_church_application`, which makes the account a church_admin
/// in `pending_verification` and creates an unpublished church row. The app
/// then shows the pending screen until a system admin verifies it.
struct ChurchApplicationView: View {
    @EnvironmentObject private var appState: AppState

    @State private var contactName = ""
    @State private var churchName = ""
    @State private var city = ""
    @State private var denomination = ""
    @State private var style = ""
    @State private var youtube = ""
    @State private var website = ""
    @State private var contactEmail = ""

    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var isValid: Bool {
        !churchName.trimmingCharacters(in: .whitespaces).isEmpty
            && !city.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tell us about your church")
                        .font(.coDisplay(26, weight: .semibold))
                        .foregroundColor(.coInk)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("This creates your church profile. A team member reviews new churches before they go live in the app.")
                        .font(.coUI(14))
                        .foregroundColor(.coInkSecondary)
                        .lineSpacing(3)
                }
                .padding(.top, 8)

                ChurchTextField(label: "Your name", placeholder: "Contact person", text: $contactName)
                ChurchTextField(label: "Church name", placeholder: "e.g. Grace Chapel", text: $churchName)
                ChurchTextField(label: "City", placeholder: "e.g. Austin, TX", text: $city)
                ChurchTextField(label: "Denomination (optional)", placeholder: "e.g. Non-denominational", text: $denomination)
                ChurchTextField(label: "Service style (optional)", placeholder: "e.g. Contemporary", text: $style)
                ChurchTextField(label: "YouTube channel (optional)", placeholder: "@handle or channel URL", text: $youtube,
                                autocapitalization: .never, keyboard: .URL, autocorrect: false)
                ChurchTextField(label: "Website (optional)", placeholder: "https://…", text: $website,
                                autocapitalization: .never, keyboard: .URL, autocorrect: false)
                ChurchTextField(label: "Contact email (optional)", placeholder: "For us to reach you", text: $contactEmail,
                                autocapitalization: .never, keyboard: .emailAddress, autocorrect: false)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.coUI(13))
                        .foregroundColor(.coCrossRed)
                }

                COPrimaryButton(title: isSubmitting ? "Submitting…" : "Submit for review") {
                    submit()
                }
                .disabled(isSubmitting || !isValid)
                .opacity(isSubmitting || !isValid ? 0.5 : 1)
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
        isSubmitting = true
        Task {
            do {
                let churchID = try await SupabaseService.shared.submitChurchApplication(
                    contactName: contactName,
                    churchName: churchName,
                    city: city,
                    denomination: emptyToNil(denomination),
                    style: emptyToNil(style),
                    youtubeHandle: emptyToNil(youtube),
                    websiteURL: emptyToNil(website),
                    contactEmail: emptyToNil(contactEmail)
                )
                isSubmitting = false
                appState.completeChurchApplication(churchId: churchID)
            } catch {
                isSubmitting = false
                withAnimation(.easeOut(duration: 0.2)) {
                    errorMessage = "We couldn't submit that. Please check your details and try again."
                }
            }
        }
    }

    private func emptyToNil(_ s: String) -> String? {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}

#Preview {
    ChurchApplicationView().environmentObject(AppState())
}
