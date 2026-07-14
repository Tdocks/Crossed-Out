import SwiftUI
import Foundation
import UIKit

// MARK: - Give Tab

private enum GiveTab: String, CaseIterable, Hashable {
    case give = "Give"
    case projects = "Projects"
}

// MARK: - Give

struct GiveView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedTab: GiveTab = .give
    @State private var giveSheetProject: GiveProject?

    private let generalFundProject = GiveProject(
        title: "General Fund", org: "Wherever it's needed most",
        raised: 0, goal: 0, dateRange: nil
    )

    var body: some View {
        ZStack {
            Color.coPaper.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    segmentedControl

                    if selectedTab == .give {
                        heroBlock
                    }

                    activeProjectsSection
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

    // MARK: Segmented Control

    private var segmentedControl: some View {
        HStack(spacing: 28) {
            ForEach(GiveTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 8) {
                        Text(tab.rawValue)
                            .font(.coUI(14, weight: selectedTab == tab ? .semibold : .regular))
                            .foregroundColor(selectedTab == tab ? .coInk : .coInkSecondary)
                        Rectangle()
                            .fill(selectedTab == tab ? Color.coCrossRed : Color.clear)
                            .frame(height: 2)
                    }
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    // MARK: Hero

    private var heroBlock: some View {
        ZStack(alignment: .bottomLeading) {
            Rectangle()
                .fill(Color(hex: "3B372F"))
                .frame(maxWidth: .infinity)
                .frame(height: 210)
                .overlay(
                    COIcon(.give, size: 44, color: Color.white.opacity(0.14))
                        .offset(y: -28)
                )
            VStack {
                Spacer()
                LinearGradient(
                    colors: [Color.black.opacity(0.0), Color.black.opacity(0.35)],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 130)
            }
            VStack(alignment: .leading, spacing: 14) {
                Text("Make an eternal impact today.")
                    .font(.coDisplay(24, weight: .semibold))
                    .foregroundColor(.white)
                CompactPrimaryButton(title: "Give Now", width: 120) {
                    giveSheetProject = generalFundProject
                }
            }
            .padding(16)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: Active Projects

    private var activeProjectsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            COSectionHeader(title: "Active Projects")
            if appState.projects.isEmpty {
                COEmptyState(
                    icon: .give,
                    title: "No active projects",
                    message: "New giving opportunities are coming soon."
                )
            } else {
                VStack(spacing: 12) {
                    ForEach(appState.projects) { project in
                        ProjectCard(project: project) {
                            giveSheetProject = project
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Project Card

fileprivate struct ProjectCard: View {
    let project: GiveProject
    let action: () -> Void

    private var tint: Color {
        project.dateRange != nil ? .coGold : .coCrossRed
    }

    var body: some View {
        Button(action: action) {
            COCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        COPlaceholderBlock(icon: .give, cornerRadius: 10, iconSize: 18)
                            .frame(width: 40, height: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(project.title)
                                .font(.coUI(15, weight: .semibold))
                                .foregroundColor(.coInk)
                            Text(project.org)
                                .font(.coUI(12))
                                .foregroundColor(.coInkTertiary)
                        }
                        Spacer()
                        Text("\(formatCurrency(project.raised)) of \(formatCurrency(project.goal))")
                            .font(.coUI(12, weight: .semibold))
                            .foregroundColor(.coInk)
                        COIcon(.chevronRight, size: 14, color: .coInkTertiary)
                    }
                    COProgressBar(value: project.progress, tint: tint)
                    if let dateRange = project.dateRange {
                        Text(dateRange)
                            .font(.coUI(11))
                            .foregroundColor(.coInkTertiary)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func formatCurrency(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        let number = formatter.string(from: NSNumber(value: value)) ?? "\(value)"
        return "$\(number)"
    }
}

// MARK: - Give Link-Out Sheet

fileprivate struct GiveLinkOutSheet: View {
    let project: GiveProject

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    private var resolvedURL: URL {
        if let donateURL = project.donateURL, let url = URL(string: donateURL) {
            return url
        }
        let query = "\(project.org) \(project.title) donate"
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return URL(string: "https://www.google.com/search?q=\(encoded)")!
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
        }
        .padding(20)
        .presentationDetents([.medium])
    }

    private func continueToGive() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        let projectID = project.id
        Task {
            await SupabaseService.shared.recordGiveIntent(projectID: projectID, amount: 0)
        }
        openURL(resolvedURL)
        dismiss()
    }
}

// MARK: - Compact Primary Button

fileprivate struct CompactPrimaryButton: View {
    let title: String
    var width: CGFloat = 120
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.coUI(14, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: width, height: 40)
                .background(Color.coCrossRed)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
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
