import SwiftUI
import Foundation
import UIKit

// MARK: - Church Finder

struct ChurchFinderView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showFilter = false
    @State private var savedChurchIDs: Set<UUID> = []

    var body: some View {
        ZStack {
            Color.coPaper.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Find a Church")
                        .font(.coDisplay(26, weight: .semibold))
                        .foregroundColor(.coInk)
                        .padding(.top, 8)

                    locationRow

                    if appState.churches.isEmpty {
                        COEmptyState(
                            icon: .church,
                            title: "No churches found",
                            message: "Try widening your search area."
                        )
                    } else {
                        VStack(spacing: 12) {
                            ForEach(appState.churches) { church in
                                churchRow(church)
                            }
                        }
                    }

                    footer
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 90)
            }
        }
        .sheet(isPresented: $showFilter) {
            ChurchFilterSheet()
        }
        .task { await loadSavedChurchIDs() }
    }

    private func loadSavedChurchIDs() async {
        guard let ids = try? await SupabaseService.shared.fetchSavedChurchIDs() else { return }
        await MainActor.run {
            savedChurchIDs = ids
        }
    }

    private func toggleSaved(_ church: Church) {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        let churchID = church.id
        let newValue = !savedChurchIDs.contains(churchID)
        withAnimation(.easeOut(duration: 0.2)) {
            if newValue {
                savedChurchIDs.insert(churchID)
            } else {
                savedChurchIDs.remove(churchID)
            }
        }
        Task {
            await SupabaseService.shared.setChurchSaved(churchID: churchID, saved: newValue)
        }
    }

    // MARK: Location Row

    private var locationRow: some View {
        HStack(spacing: 8) {
            COIcon(.mapPin, size: 16, color: .coInkSecondary)
            Text("Charlotte, NC")
                .font(.coUI(14))
                .foregroundColor(.coInk)
            Spacer()
            Button {
                showFilter = true
            } label: {
                Text("Filter")
                    .font(.coUI(13))
                    .foregroundColor(.coInkSecondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .overlay(
                        Capsule().strokeBorder(Color.coDivider, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Church Row

    private func churchRow(_ church: Church) -> some View {
        let isSaved = savedChurchIDs.contains(church.id)
        return COCard {
            HStack(spacing: 12) {
                monogram(for: church)
                VStack(alignment: .leading, spacing: 4) {
                    Text(church.name)
                        .font(.coUI(15, weight: .semibold))
                        .foregroundColor(.coInk)
                    Text("\(String(format: "%.1f", church.rating)) ★ · \(church.style)")
                        .font(.coUI(12))
                        .foregroundColor(.coInkSecondary)
                }
                Spacer()
                Text(String(format: "%.1f mi", church.distanceMiles))
                    .font(.coUI(12))
                    .foregroundColor(.coInkTertiary)
                Button {
                    toggleSaved(church)
                } label: {
                    COIcon(.heart, size: 18, color: isSaved ? .coCrossRed : .coInkTertiary)
                        .padding(.leading, 4)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func monogram(for church: Church) -> some View {
        let tint = accentColor(church.accent)
        return ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(tint.opacity(0.12))
            Text(String(church.name.prefix(1)))
                .font(.coDisplay(20, weight: .semibold))
                .foregroundColor(tint)
        }
        .frame(width: 44, height: 44)
    }

    private func accentColor(_ name: String) -> Color {
        switch name {
        case "coCrossRed": return .coCrossRed
        case "coBlue": return .coBlue
        case "coOlive": return .coOlive
        case "coGold": return .coGold
        default: return .coInkSecondary
        }
    }

    // MARK: Footer

    private var footer: some View {
        VStack(spacing: 6) {
            Text("Can't find what you're looking for?")
                .font(.coUI(12))
                .foregroundColor(.coInkTertiary)
            Button {} label: {
                Text("Suggest a Church")
                    .font(.coUI(13, weight: .semibold))
                    .foregroundColor(.coCrossRed)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
    }
}

// MARK: - Filter Sheet

fileprivate struct ChurchFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<String> = []

    private let options = ["Contemporary", "Traditional", "Bible Teaching", "Worship", "Young Adults", "Family"]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.coPaper.ignoresSafeArea()
                VStack(spacing: 24) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 10)], spacing: 10) {
                        ForEach(options, id: \.self) { option in
                            COChip(text: option, selected: selected.contains(option)) {
                                toggle(option)
                            }
                        }
                    }
                    Spacer()
                    COPrimaryButton(title: "Apply") {
                        dismiss()
                    }
                }
                .padding(20)
            }
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func toggle(_ option: String) {
        if selected.contains(option) {
            selected.remove(option)
        } else {
            selected.insert(option)
        }
    }
}

// MARK: - Preview

#Preview {
    ChurchFinderView()
        .environmentObject(AppState())
}
