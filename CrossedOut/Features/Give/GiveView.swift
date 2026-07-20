import SwiftUI
import Foundation
import UIKit

// MARK: - Give
//
// Give is a curated HUB of external giving destinations, not a fundraising
// platform. Crossed Out never touches the money: every "Give Now" opens the
// organization's own real donation page in the browser. There are no
// progress bars, no "$X of $Y raised", no donor counts -- those were
// fabricated in the old design and are a launch blocker. If a destination
// doesn't have a verified real `donate_url`, it must render as a disabled
// "coming soon" card and must NEVER fall back to a search-engine guess.

struct GiveView: View {
    @EnvironmentObject private var appState: AppState
    @State private var giveSheetProject: GiveProject?

    /// Real destinations only. `hasRealDonateURL` is the guardrail: a row
    /// with no (or malformed) donate_url never gets a live "Give Now" here.
    private var destinations: [GiveProject] { appState.projects }

    var body: some View {
        ZStack {
            Color.coPaper.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    introBlock
                    destinationsSection
                    honestyNote
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 90)
            }
        }
        .sheet(item: $giveSheetProject) { project in
            GiveLinkOutSheet(project: project)
        }
    }

    // MARK: Intro

    private var introBlock: some View {
        ZStack(alignment: .bottomLeading) {
            Rectangle()
                .fill(Color(hex: "3B372F"))
                .frame(maxWidth: .infinity)
                .frame(height: 150)
                .overlay(
                    COIcon(.give, size: 40, color: Color.white.opacity(0.14))
                        .offset(y: -14)
                )
            VStack {
                Spacer()
                LinearGradient(
                    colors: [Color.black.opacity(0.0), Color.black.opacity(0.35)],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 100)
            }
            Text("A few places to give.")
                .font(.coDisplay(24, weight: .semibold))
                .foregroundColor(.white)
                .padding(16)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: Destinations

    private var destinationsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            COSectionHeader(title: "Giving Destinations")
            if destinations.isEmpty {
                COEmptyState(
                    icon: .give,
                    title: "More ministries coming soon",
                    message: "We're verifying real giving pages for local churches and causes before adding them here."
                )
            } else {
                VStack(spacing: 12) {
                    ForEach(Array(destinations.enumerated()), id: \.element.id) { index, project in
                        DestinationCard(project: project, featured: index == 0) {
                            guard project.hasRealDonateURL else { return }
                            giveSheetProject = project
                        }
                    }
                }
                if destinations.count < 4 {
                    moreComingSoonRow
                }
            }
        }
    }

    private var moreComingSoonRow: some View {
        HStack(spacing: 10) {
            COIcon(.church, size: 16, color: .coInkTertiary)
            Text("More ministries are on the way.")
                .font(.coUI(12))
                .foregroundColor(.coInkTertiary)
        }
        .padding(.top, 2)
    }

    // MARK: Honesty Note

    private var honestyNote: some View {
        COCard {
            VStack(alignment: .leading, spacing: 6) {
                Text("How giving works here")
                    .font(.coUI(13, weight: .semibold))
                    .foregroundColor(.coInk)
                Text("Tapping Give Now opens the organization's own secure giving page in your browser. Crossed Out never handles or touches your donation. Direct, in-app giving to specific local causes is on the way.")
                    .font(.coUI(12))
                    .foregroundColor(.coInkSecondary)
                    .lineSpacing(2)
            }
        }
    }
}

// MARK: - Destination Card

fileprivate struct DestinationCard: View {
    let project: GiveProject
    var featured: Bool = false
    let action: () -> Void

    var body: some View {
        COCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    COPlaceholderBlock(icon: .church, cornerRadius: 10, iconSize: 18)
                        .frame(width: 44, height: 44)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Text(project.title)
                                .font(.coUI(15, weight: .semibold))
                                .foregroundColor(.coInk)
                            if featured {
                                FeaturedTag()
                            }
                        }
                        HStack(spacing: 4) {
                            COIcon(.mapPin, size: 11, color: .coInkTertiary)
                            Text(project.org)
                                .font(.coUI(12))
                                .foregroundColor(.coInkTertiary)
                        }
                        if let category = project.category, !category.isEmpty {
                            CategoryTag(text: category)
                        }
                    }
                    Spacer(minLength: 0)
                }

                if let description = project.description, !description.isEmpty {
                    Text(description)
                        .font(.coUI(13))
                        .foregroundColor(.coInkSecondary)
                        .lineSpacing(2)
                }

                if project.hasRealDonateURL {
                    Button(action: action) {
                        Text("Give Now")
                            .font(.coUI(14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                            .background(Color.coCrossRed)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                } else {
                    // Guardrail: no real donate_url means no live button --
                    // this must be visually unmistakable from a working one,
                    // and it must never open a search-engine guess.
                    HStack {
                        Spacer()
                        Text("Coming Soon")
                            .font(.coUI(14, weight: .semibold))
                            .foregroundColor(.coInkTertiary)
                        Spacer()
                    }
                    .frame(height: 42)
                    .background(Color.coPaperSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
    }
}

fileprivate struct FeaturedTag: View {
    var body: some View {
        Text("FEATURED")
            .font(.coUI(9, weight: .bold))
            .tracking(0.5)
            .foregroundColor(.coCrossRed)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(Color.coCrossRed.opacity(0.1))
            )
    }
}

fileprivate struct CategoryTag: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.coUI(11, weight: .medium))
            .foregroundColor(.coOlive)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(Color.coOlive.opacity(0.1))
            )
            .padding(.top, 2)
    }
}

// MARK: - Give Link-Out Sheet

fileprivate struct GiveLinkOutSheet: View {
    let project: GiveProject

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    /// Guardrail: only a real, well-formed http(s) URL is ever opened here.
    /// There is no search-engine or guessed-URL fallback -- if this is nil
    /// the "Continue to Give" button below simply does nothing rather than
    /// send someone somewhere Crossed Out never verified.
    private var destinationURL: URL? {
        guard project.hasRealDonateURL, let donateURL = project.donateURL else { return nil }
        return URL(string: donateURL)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text(project.title)
                    .font(.coDisplay(20, weight: .semibold))
                    .foregroundColor(.coInk)
                Text(project.org)
                    .font(.coUI(13))
                    .foregroundColor(.coInkTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("Giving happens directly with the organization. Crossed Out never touches your donation.")
                .font(.coUI(13))
                .foregroundColor(.coInkSecondary)

            Spacer()

            COPrimaryButton(title: "Continue to Give") {
                continueToGive()
            }
            .disabled(destinationURL == nil)
            .opacity(destinationURL == nil ? 0.5 : 1)
        }
        .padding(20)
        .presentationDetents([.medium])
    }

    private func continueToGive() {
        guard let destinationURL else { return }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        let projectID = project.id
        Task {
            await SupabaseService.shared.recordGiveIntent(projectID: projectID, amount: 0)
        }
        openURL(destinationURL)
        dismiss()
    }
}

// MARK: - Placeholder Block

fileprivate struct COPlaceholderBlock: View {
    var icon: COIconName
    var cornerRadius: CGFloat = 12
    var iconSize: CGFloat = 28

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.coPaperSecondary)
            .overlay(
                COIcon(icon, size: iconSize, color: .coInkSecondary)
                    .opacity(0.25)
            )
    }
}

// MARK: - Preview

#Preview {
    GiveView()
        .environmentObject(AppState())
}
