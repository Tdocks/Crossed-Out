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
            GiveAmountSheet(project: project)
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
            VStack(spacing: 12) {
                ForEach(MockData.giveProjects) { project in
                    ProjectCard(project: project) {
                        giveSheetProject = project
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

// MARK: - Give Amount Sheet

fileprivate struct GiveAmountSheet: View {
    let project: GiveProject

    @Environment(\.dismiss) private var dismiss
    @State private var selectedAmount: Int? = 25
    @State private var customAmount: String = ""
    @State private var didSucceed = false

    private let amounts = [10, 25, 50, 100]

    private var amountValue: Double? {
        if let selectedAmount { return Double(selectedAmount) }
        if let custom = Double(customAmount), custom > 0 { return custom }
        return nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.coPaper.ignoresSafeArea()
                if didSucceed {
                    successState
                } else {
                    formState
                }
            }
            .navigationTitle("Give Now")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var formState: some View {
        VStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 6) {
                Text(project.title)
                    .font(.coDisplay(20, weight: .semibold))
                    .foregroundColor(.coInk)
                Text(project.org)
                    .font(.coUI(13))
                    .foregroundColor(.coInkTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 10) {
                ForEach(amounts, id: \.self) { amount in
                    COChip(text: "$\(amount)", selected: selectedAmount == amount) {
                        selectedAmount = amount
                        customAmount = ""
                    }
                }
            }
            TextField("Other amount", text: $customAmount)
                .keyboardType(.numberPad)
                .font(.coUI(15))
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.coCard)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.coDivider, lineWidth: 1)
                )
                .onChange(of: customAmount) { _, newValue in
                    if !newValue.isEmpty { selectedAmount = nil }
                }
            Spacer()
            COPrimaryButton(title: giveButtonTitle) {
                submitGive()
            }
        }
        .padding(20)
    }

    private var giveButtonTitle: String {
        guard let amountValue, amountValue > 0 else { return "Give" }
        return "Give \(formattedAmount(amountValue))"
    }

    private var successState: some View {
        VStack(spacing: 14) {
            Spacer()
            COIcon(.checkCircle, size: 40, color: .coGold)
            Text("Thank you.")
                .font(.coDisplay(22, weight: .semibold))
                .foregroundColor(.coInk)
            Text("Your gift intent was recorded. Payment processing arrives in a future update.")
                .font(.coUI(13))
                .foregroundColor(.coInkSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func formattedAmount(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.maximumFractionDigits = value == value.rounded() ? 0 : 2
        let number = formatter.string(from: NSNumber(value: value)) ?? "\(value)"
        return "$\(number)"
    }

    private func submitGive() {
        guard let amountValue, amountValue > 0, !didSucceed else { return }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        let projectID = project.id
        Task {
            await SupabaseService.shared.recordGiveIntent(projectID: projectID, amount: amountValue)
        }
        withAnimation(.easeOut(duration: 0.25)) {
            didSucceed = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            dismiss()
        }
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
}
