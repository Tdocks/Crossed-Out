import SwiftUI

/// Portal base URL for church invite links. Set this to wherever the church
/// portal (church-portal.html) is hosted. The `?invite=<token>` query is
/// appended to it. See RBAC_AND_PORTAL_RUNBOOK.md.
enum PortalConfig {
    static let baseURL = "https://crossedout-church-portal.pages.dev"
}

/// System-admin console (Tyler). Two jobs: verify churches that self-signed
/// up in the app, and mint invite links to hand to church reps you've spoken
/// with (those auto-approve on signup).
struct AdminHubView: View {
    @State private var pending: [PendingChurch] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    // Invite generator
    @State private var inviteChurchName = ""
    @State private var inviteEmail = ""
    @State private var generatedLink: String?
    @State private var isGenerating = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Admin")
                    .font(.coDisplay(28, weight: .semibold))
                    .foregroundColor(.coInk)
                    .padding(.top, 8)

                NavigationLink { AddChurchView() } label: {
                    HStack(spacing: 12) {
                        COIcon(.mapPin, size: 20, color: .coCrossRed)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Add a church")
                                .font(.coUI(16, weight: .semibold))
                                .foregroundColor(.coInk)
                            Text("Resolve a YouTube channel + go live in Attend")
                                .font(.coUI(12))
                                .foregroundColor(.coInkSecondary)
                        }
                        Spacer()
                        COIcon(.chevronRight, size: 16, color: .coInkTertiary)
                    }
                    .padding(16)
                    .background(Color.coCard)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.coDivider, lineWidth: 1))
                }
                .buttonStyle(.plain)

                NavigationLink { ModerationQueueView() } label: {
                    HStack(spacing: 12) {
                        COIcon(.heart, size: 20, color: .coCrossRed)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Moderation queue")
                                .font(.coUI(16, weight: .semibold))
                                .foregroundColor(.coInk)
                            Text("Review reported community content")
                                .font(.coUI(12))
                                .foregroundColor(.coInkSecondary)
                        }
                        Spacer()
                        COIcon(.chevronRight, size: 16, color: .coInkTertiary)
                    }
                    .padding(16)
                    .background(Color.coCard)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.coDivider, lineWidth: 1))
                }
                .buttonStyle(.plain)

                inviteSection
                pendingSection

                Spacer(minLength: 60)
            }
            .padding(.horizontal, 22)
        }
        .background(Color.coPaper.ignoresSafeArea())
        .task { await loadPending() }
    }

    // MARK: Invite generator

    private var inviteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("INVITE A CHURCH")
            Text("Generate a link for a church rep. Anyone who signs up through it is auto-approved.")
                .font(.coUI(13))
                .foregroundColor(.coInkSecondary)

            ChurchTextField(label: "Church name (optional)", placeholder: "Pre-fills their form", text: $inviteChurchName)
            ChurchTextField(label: "Their email (optional)", placeholder: "For your records", text: $inviteEmail,
                            autocapitalization: .never, keyboard: .emailAddress, autocorrect: false)

            COPrimaryButton(title: isGenerating ? "Generating…" : "Generate invite link") {
                generate()
            }
            .disabled(isGenerating)
            .opacity(isGenerating ? 0.5 : 1)

            if let generatedLink {
                VStack(alignment: .leading, spacing: 8) {
                    Text(generatedLink)
                        .font(.coUI(12))
                        .foregroundColor(.coInk)
                        .textSelection(.enabled)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.coCard)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.coDivider, lineWidth: 1))
                    HStack(spacing: 10) {
                        Button {
                            UIPasteboard.general.string = generatedLink
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                                .font(.coUI(13, weight: .medium))
                                .foregroundColor(.coInk)
                        }
                        ShareLink(item: generatedLink) {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .font(.coUI(13, weight: .medium))
                                .foregroundColor(.coInk)
                        }
                    }
                }
            }
            if let errorMessage {
                Text(errorMessage).font(.coUI(12)).foregroundColor(.coCrossRed)
            }
        }
        .padding(16)
        .background(Color.coCard)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.coDivider, lineWidth: 1))
    }

    // MARK: Pending list

    private var pendingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("PENDING CHURCHES")
            if isLoading {
                ProgressView().padding(.vertical, 20)
            } else if pending.isEmpty {
                Text("No churches waiting for review.")
                    .font(.coUI(14))
                    .foregroundColor(.coInkSecondary)
            } else {
                ForEach(pending) { church in
                    pendingRow(church)
                }
            }
        }
    }

    private func pendingRow(_ church: PendingChurch) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(church.churchName ?? "Unnamed church")
                .font(.coUI(16, weight: .semibold))
                .foregroundColor(.coInk)
            if let city = church.city {
                Text(city).font(.coUI(13)).foregroundColor(.coInkSecondary)
            }
            if let email = church.contactEmail {
                Text(email).font(.coUI(12)).foregroundColor(.coInkTertiary)
            }
            if let yt = church.youtubeHandle, !yt.isEmpty {
                Text("YouTube: \(yt)").font(.coUI(12)).foregroundColor(.coInkTertiary)
            }
            HStack(spacing: 10) {
                Button { Task { await verify(church, approve: true) } } label: {
                    Text("Verify")
                        .font(.coUI(14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.vertical, 8).padding(.horizontal, 18)
                        .background(Color.coOlive)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                Button { Task { await verify(church, approve: false) } } label: {
                    Text("Reject")
                        .font(.coUI(14, weight: .semibold))
                        .foregroundColor(.coCrossRed)
                        .padding(.vertical, 8).padding(.horizontal, 18)
                        .overlay(Capsule().strokeBorder(Color.coCrossRed, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.coCard)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.coDivider, lineWidth: 1))
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.coUI(11, weight: .medium))
            .foregroundColor(.coInkTertiary)
            .tracking(1.2)
    }

    // MARK: Actions

    private func loadPending() async {
        isLoading = true
        pending = (try? await SupabaseService.shared.adminListPendingChurches()) ?? []
        isLoading = false
    }

    private func verify(_ church: PendingChurch, approve: Bool) async {
        do {
            if approve {
                try await SupabaseService.shared.adminVerifyChurchAccount(userID: church.userId)
            } else {
                try await SupabaseService.shared.adminRejectChurchAccount(userID: church.userId)
            }
            await loadPending()
        } catch {
            withAnimation { errorMessage = "That action didn't go through. Try again." }
        }
    }

    private func generate() {
        errorMessage = nil
        isGenerating = true
        Task {
            do {
                let token = try await SupabaseService.shared.createChurchInvite(
                    churchName: inviteChurchName.isEmpty ? nil : inviteChurchName,
                    contactEmail: inviteEmail.isEmpty ? nil : inviteEmail
                )
                generatedLink = "\(PortalConfig.baseURL)?invite=\(token)"
                isGenerating = false
            } catch {
                isGenerating = false
                withAnimation { errorMessage = "Couldn't generate a link. Are you a system admin?" }
            }
        }
    }
}

#Preview {
    AdminHubView()
}
