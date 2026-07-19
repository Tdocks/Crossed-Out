import SwiftUI
import UIKit

// MARK: - Explore
//
// Discovery surface backed by explore_items (migration 0037). Single-select
// TABS: exactly one vertical is shown at a time (Sermons default). Tapping an
// item hands the user OUT to the source app via its universal link. No
// third-party media is played or reproduced in-app.

struct ExploreView: View {
    @Environment(\.openURL) private var openURL

    @State private var items: [ExploreItem] = []
    @State private var isLoading = true
    @State private var loadFailed = false
    @State private var searchText: String = ""
    @State private var selectedVertical: ExploreVertical = .sermons

    private var orderedVerticals: [ExploreVertical] {
        ExploreVertical.allCases.sorted { $0.order < $1.order }
    }

    var body: some View {
        ZStack {
            Color.coPaper.ignoresSafeArea()
            content
        }
        .task { await loadIfNeeded() }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView().tint(.coInkTertiary)
        } else if loadFailed {
            COEmptyState(
                icon: .search,
                title: "Couldn't load Explore",
                message: "Check your connection and try again.",
                actionTitle: "Retry",
                action: { Task { await reload() } }
            )
            .padding(.horizontal, 20)
        } else {
            VStack(spacing: 0) {
                VStack(spacing: 14) {
                    searchField
                    tabBar
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 14)

                ScrollView {
                    tabContent
                        .padding(.horizontal, 20)
                        .padding(.bottom, 90)
                }
            }
        }
    }

    // MARK: Search

    private var searchField: some View {
        HStack(spacing: 8) {
            COIcon(.search, size: 17, color: .coInkTertiary)
            TextField("Search \(selectedVertical.chipTitle.lowercased())", text: $searchText)
                .font(.coUI(15))
                .foregroundColor(.coInk)
                .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    COIcon(.crossOut, size: 15, color: .coInkTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.coCard)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.coDivider, lineWidth: 1)
        )
    }

    // MARK: Tab bar (single-select)

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(orderedVerticals) { vertical in
                    COChip(text: vertical.chipTitle, selected: selectedVertical == vertical) {
                        guard selectedVertical != vertical else { return }
                        UISelectionFeedbackGenerator().selectionChanged()
                        withAnimation(.easeInOut(duration: 0.15)) { selectedVertical = vertical }
                    }
                }
            }
            .padding(.vertical, 1)
        }
    }

    // MARK: Active tab content

    @ViewBuilder
    private var tabContent: some View {
        if selectedVertical.isComingSoon {
            VStack(alignment: .leading, spacing: 14) {
                ComingSoonCard(icon: selectedVertical.icon, message: selectedVertical.comingSoonMessage)
            }
            .padding(.top, 8)
        } else {
            let matches = filteredItems(for: selectedVertical)
            if matches.isEmpty {
                COEmptyState(
                    icon: searchText.isEmpty ? .study : .search,
                    title: searchText.isEmpty ? "Nothing here yet" : "No matches",
                    message: searchText.isEmpty
                        ? "Fresh \(selectedVertical.chipTitle.lowercased()) is on the way. Check back soon."
                        : "Try a different search or clear it."
                )
                .padding(.top, 28)
            } else if selectedVertical == .devotionals {
                VStack(spacing: 12) {
                    ForEach(matches) { item in
                        DevotionalRow(item: item) { open(item) }
                    }
                }
                .padding(.top, 4)
            } else {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)],
                    spacing: 20
                ) {
                    ForEach(matches) { item in
                        ExplorePosterCard(item: item) { open(item) }
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    private func filteredItems(for vertical: ExploreVertical) -> [ExploreItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return items.filter { item in
            guard item.vertical == vertical else { return false }
            guard !query.isEmpty else { return true }
            return item.title.lowercased().contains(query)
                || (item.subtitle?.lowercased().contains(query) ?? false)
                || (item.excerpt?.lowercased().contains(query) ?? false)
        }
    }

    // MARK: Actions

    private func open(_ item: ExploreItem) {
        guard let url = item.handoffURL else { return }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        openURL(url)
    }

    private func loadIfNeeded() async {
        if items.isEmpty && !loadFailed { await reload() }
    }

    private func reload() async {
        isLoading = true
        loadFailed = false
        do {
            items = try await SupabaseService.shared.fetchExploreItems()
            loadFailed = false
        } catch {
            print("ExploreView: fetch failed: \(error)")
            loadFailed = true
        }
        isLoading = false
    }
}

// MARK: - Poster Card (music / sermons / events) — flexes to grid cell width

fileprivate struct ExplorePosterCard: View {
    let item: ExploreItem
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                ExploreThumb(url: item.thumbnailURL, icon: item.vertical.icon)
                    .aspectRatio(3.0 / 2.0, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                Text(item.title)
                    .font(.coUI(13, weight: .semibold))
                    .foregroundColor(.coInk)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let subtitle = item.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.coUI(11))
                        .foregroundColor(.coInkTertiary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Devotional Row (text-forward)

fileprivate struct DevotionalRow: View {
    let item: ExploreItem
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            COCard {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        COIcon(.journal, size: 16, color: .coOlive)
                        Text(item.subtitle ?? "Devotional")
                            .font(.coUI(11, weight: .semibold))
                            .foregroundColor(.coInkTertiary)
                        Spacer()
                        COIcon(.chevronRight, size: 14, color: .coInkTertiary)
                    }
                    Text(item.title)
                        .font(.coDisplay(17, weight: .semibold))
                        .foregroundColor(.coInk)
                        .multilineTextAlignment(.leading)
                    if let excerpt = item.excerpt, !excerpt.isEmpty {
                        Text(excerpt)
                            .font(.coUI(13))
                            .foregroundColor(.coInkSecondary)
                            .lineSpacing(3)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Thumbnail

fileprivate struct ExploreThumb: View {
    let url: String?
    let icon: COIconName

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.coPaperSecondary)
                .overlay(COIcon(icon, size: 26, color: .coInkSecondary).opacity(0.25))
            if let url, let imageURL = URL(string: url) {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    default:
                        Color.clear
                    }
                }
            }
        }
        .clipped()
    }
}

// MARK: - Coming Soon Card

fileprivate struct ComingSoonCard: View {
    let icon: COIconName
    let message: String

    var body: some View {
        COCard {
            HStack(spacing: 14) {
                ExploreThumb(url: nil, icon: icon)
                    .frame(width: 52, height: 52)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Coming soon")
                        .font(.coUI(11, weight: .semibold))
                        .foregroundColor(.coGold)
                        .textCase(.uppercase)
                    Text(message)
                        .font(.coUI(13))
                        .foregroundColor(.coInkSecondary)
                        .lineSpacing(3)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ExploreView()
}
