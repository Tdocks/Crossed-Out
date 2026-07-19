import SwiftUI
import Foundation
import UIKit

// MARK: - Church Finder

struct ChurchFinderView: View {
    @EnvironmentObject private var appState: AppState
    @State private var savedChurchIDs: Set<UUID> = []
    @State private var selectedStyleFilter: String = "All"

    private let filterOptions = ["All", "Contemporary", "Worship", "Bible Teaching", "Teaching"]

    private var filteredChurches: [Church] {
        guard selectedStyleFilter != "All" else { return appState.churches }
        return appState.churches.filter { $0.style == selectedStyleFilter }
    }

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

                    if appState.attendLoading {
                        loadingState
                    } else if appState.attendLoadFailed {
                        COEmptyState(
                            icon: .church,
                            title: "Couldn't load churches",
                            message: "Check your connection and try again.",
                            actionTitle: "Try Again",
                            action: { Task { await appState.retryAttend() } }
                        )
                    } else if appState.churches.isEmpty {
                        COEmptyState(
                            icon: .church,
                            title: "No churches found",
                            message: "Try widening your search area."
                        )
                    } else if filteredChurches.isEmpty {
                        COEmptyState(
                            icon: .church,
                            title: "No churches match this filter",
                            message: "Try a different style, or choose All to see everything nearby."
                        )
                    } else {
                        VStack(spacing: 12) {
                            ForEach(filteredChurches) { church in
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

    // MARK: Loading

    private var loadingState: some View {
        VStack(spacing: 14) {
            ProgressView()
                .tint(.coCrossRed)
            Text("Loading churches…")
                .font(.coUI(13))
                .foregroundColor(.coInkSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: Location Row

    private var locationRow: some View {
        HStack(spacing: 8) {
            COIcon(.mapPin, size: 16, color: .coInkSecondary)
            Text("Charlotte, NC")
                .font(.coUI(14))
                .foregroundColor(.coInk)
            Spacer()
            Menu {
                ForEach(filterOptions, id: \.self) { option in
                    Button {
                        selectedStyleFilter = option
                    } label: {
                        if option == selectedStyleFilter {
                            Label(option, systemImage: "checkmark")
                        } else {
                            Text(option)
                        }
                    }
                }
            } label: {
                Text(selectedStyleFilter == "All" ? "Filter" : selectedStyleFilter)
                    .font(.coUI(13))
                    .foregroundColor(selectedStyleFilter == "All" ? .coInkSecondary : .coCrossRed)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .overlay(
                        Capsule().strokeBorder(selectedStyleFilter == "All" ? Color.coDivider : Color.coCrossRed, lineWidth: 1)
                    )
            }
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

    /// Maps a church's `accent` string to a Color token. The DB seeds store
    /// short names ("red"/"blue"/"olive"/"gold" — see supabase/migrations),
    /// while older mock data used design-token-style names ("coCrossRed"/
    /// "coBlue"/"coOlive"/"coGold"). Matching case-insensitively on a
    /// substring keeps both forms working and is robust to either source.
    private func accentColor(_ name: String) -> Color {
        let normalized = name.lowercased()
        if normalized.contains("red") { return .coCrossRed }
        if normalized.contains("blue") { return .coBlue }
        if normalized.contains("olive") { return .coOlive }
        if normalized.contains("gold") { return .coGold }
        return .coInkSecondary
    }

    // MARK: Footer

    private var footer: some View {
        VStack(spacing: 6) {
            Text("Can't find what you're looking for?")
                .font(.coUI(12))
                .foregroundColor(.coInkTertiary)
            Button { openSuggestChurchEmail() } label: {
                Text("Suggest a Church")
                    .font(.coUI(13, weight: .semibold))
                    .foregroundColor(.coCrossRed)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
    }

    /// Opens the system mail composer addressed to support with a preset
    /// subject, so users can suggest a church without any new backend.
    private func openSuggestChurchEmail() {
        let subject = "Suggest a Church"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "Suggest%20a%20Church"
        guard let url = URL(string: "mailto:tdoxwell@icloud.com?subject=\(subject)") else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - Preview

#Preview {
    ChurchFinderView()
        .environmentObject(AppState())
}
