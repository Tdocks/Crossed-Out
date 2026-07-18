import SwiftUI

/// Lets a church_admin edit the church they manage. Loads the current church
/// (visible to its own admin even while unpublished, via RLS), prefills the
/// form, and saves through the `update_my_church` RPC.
struct ChurchManageView: View {
    @EnvironmentObject private var appState: AppState

    @State private var church: Church?
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var savedTick = false
    @State private var errorMessage: String?

    @State private var name = ""
    @State private var city = ""
    @State private var denomination = ""
    @State private var style = ""
    @State private var youtube = ""
    @State private var website = ""
    @State private var contactEmail = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("My Church")
                    .font(.coDisplay(28, weight: .semibold))
                    .foregroundColor(.coInk)
                    .padding(.top, 8)

                if isLoading {
                    ProgressView().padding(.top, 40)
                } else if church == nil {
                    Text("We couldn't load your church right now. Pull back and try again in a moment.")
                        .font(.coUI(14))
                        .foregroundColor(.coInkSecondary)
                } else {
                    statusBadge
                    ChurchTextField(label: "Church name", placeholder: "Church name", text: $name)
                    ChurchTextField(label: "City", placeholder: "City", text: $city)
                    ChurchTextField(label: "Denomination", placeholder: "Denomination", text: $denomination)
                    ChurchTextField(label: "Service style", placeholder: "e.g. Contemporary", text: $style)
                    ChurchTextField(label: "YouTube channel", placeholder: "@handle or channel URL", text: $youtube,
                                    autocapitalization: .never, keyboard: .URL, autocorrect: false)
                    ChurchTextField(label: "Website", placeholder: "https://…", text: $website,
                                    autocapitalization: .never, keyboard: .URL, autocorrect: false)
                    ChurchTextField(label: "Contact email", placeholder: "Contact email", text: $contactEmail,
                                    autocapitalization: .never, keyboard: .emailAddress, autocorrect: false)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.coUI(13))
                            .foregroundColor(.coCrossRed)
                    }

                    COPrimaryButton(title: saveTitle) { save() }
                        .disabled(isSaving)
                        .opacity(isSaving ? 0.5 : 1)
                        .padding(.top, 4)
                        .padding(.bottom, 32)
                }
            }
            .padding(.horizontal, 24)
        }
        .background(Color.coPaper.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
        .task { await load() }
    }

    private var saveTitle: String {
        if isSaving { return "Saving…" }
        return savedTick ? "Saved ✓" : "Save changes"
    }

    @ViewBuilder
    private var statusBadge: some View {
        let published = church?.isPublished ?? true
        HStack(spacing: 8) {
            Circle()
                .fill(published ? Color.coOlive : Color.coGold)
                .frame(width: 8, height: 8)
            Text(published ? "Live in the app" : "Pending review")
                .font(.coUI(12, weight: .medium))
                .foregroundColor(.coInkSecondary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(Color.coCard)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(Color.coDivider, lineWidth: 1))
    }

    private func load() async {
        guard let churchID = appState.churchId else { isLoading = false; return }
        church = try? await SupabaseService.shared.fetchMyChurch(churchID: churchID)
        if let c = church {
            name = c.name
            city = c.city
            denomination = c.denomination ?? ""
            style = c.style
            youtube = c.youtubeHandle ?? ""
            website = c.websiteURL ?? ""
            contactEmail = c.contactEmail ?? ""
        }
        isLoading = false
    }

    private func save() {
        errorMessage = nil
        isSaving = true
        savedTick = false
        Task {
            do {
                try await SupabaseService.shared.updateMyChurch(
                    name: name, city: city,
                    denomination: emptyToNil(denomination), style: style,
                    youtubeHandle: emptyToNil(youtube), websiteURL: emptyToNil(website),
                    contactEmail: emptyToNil(contactEmail)
                )
                await load()
                isSaving = false
                withAnimation { savedTick = true }
            } catch {
                isSaving = false
                withAnimation { errorMessage = "Couldn't save those changes. Please try again." }
            }
        }
    }

    private func emptyToNil(_ s: String) -> String? {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}

#Preview {
    ChurchManageView().environmentObject(AppState())
}
