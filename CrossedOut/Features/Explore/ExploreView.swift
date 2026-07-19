import SwiftUI
import UIKit

// MARK: - Explore
//
// Discovery surface backed by explore_items (migration 0037). Content is
// ingested server-side by the explore_* edge functions and read read-only
// here; tapping any item hands the user OUT to the source app via its
// universal link. No third-party media is played or reproduced in-app.

struct ExploreView: View {
    @Environment(\.openURL) private var openURL

    @State private var items: [ExploreItem] = []
    @State private var isLoading = true
    @State private var loadFailed = false
    @State private var searchText: String = ""
    @State private var selectedVerticals: Set<ExploreVertical> = []

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
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    searchField
                    chipRow
                    feed
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 90)
            }
        }
    }

    // MARK: Search

    private var searchField: some View {
        HStack(spacing: 8) {
            COIcon(.search, size: 17, color: .coInkTertiary)
            TextField("Search Explore", text: $searchText)
                .font(.coUI(15))
                .foregroundColor(.coInk)
                .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
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

    // MARK: Chips

    private var chipRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(ExploreVertical.allCases.sorted { $0.order < $1.order }) { vertical in
                    COChip(
                        text: vertical.chipTitle,
                        selected: selectedVerticals.contains(vertical)
                    ) {
                        toggle(vertical)
                    }
                }
            }
        }
    }

    private func toggle(_ vertical: ExploreVertical) {
        if selectedVerticals.contains(vertical) {
            selectedVerticals.remove(vertical)
        } else {
            selectedVerticals.insert(vertical)
        }
    }

    // MARK: Feed

    private enum FeedRow: Identifiable {
        case data(Section)
        case comingSoon(ExploreVertical)
        var id: String {
            switch self {
            case .data(let s): return "data-\(s.vertical.rawValue)"
            case .comingSoon(let v): return "soon-\(v.rawValue)"
            }
        }
    }

    @ViewBuilder
    private var feed: some View {
        let rows = feedRows()
        if rows.isEmpty {
            COEmptyState(
                icon: searchText.isEmpty ? .study : .search,
                title: searchText.isEmpty ? "Nothing here yet" : "No matches",
                message: searchText.isEmpty
                    ? "Fresh worship, sermons, and devotionals are on the way. Check back soon."
                    : "Try a different search or clear your filters."
            )
            .padding(.top, 20)
        } else {
            ForEach(rows) { row in
                switch row {
                case .data(let section): dataSection(section)
                case .comingSoon(let vertical): comingSoonSection(vertical)
                }
            }
        }
    }

    @ViewBuilder
    private func dataSection(_ section: Section) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            COSectionHeader(title: section.vertical.sectionTitle)
            if section.vertical == .devotionals {
                VStack(spacing: 12) {
                    ForEach(section.items) { item in
                        DevotionalRow(item: item) { open(item) }
                    }
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(section.items) { item in
                            ExplorePosterCard(item: item) { open(item) }
                        }
                    }
                }
            }
        }
    }

    private func comingSoonSection(_ vertical: ExploreVertical) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            COSectionHeader(title: vertical.sectionTitle)
            ComingSoonCard(icon: vertical.icon, message: vertical.comingSoonMessage)
        }
    }

    private func feedRows() -> [FeedRow] {
        let grouped = filteredGrouped()
        let dataByVertical = Dictionary(uniqueKeysWithValues: grouped.map { ($0.vertical, $0) })
        let searching = !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let verticals = selectedVerticals.isEmpty
            ? Set(ExploreVertical.allCases) : selectedVerticals

        var rows: [FeedRow] = []
        for vertical in ExploreVertical.allCases.sorted(by: { $0.order < $1.order }) {
            guard verticals.contains(vertical) else { continue }
            if let section = dataByVertical[vertical] {
                rows.append(.data(section))
            } else if vertical.isComingSoon && !searching {
                rows.append(.comingSoon(vertical))
            }
        }
        return rows
    }

    // MARK: Filtering

    private struct Section { let vertical: ExploreVertical; let items: [ExploreItem] }

    private func filteredGrouped() -> [Section] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let verticals = selectedVerticals.isEmpty
            ? Set(ExploreVertical.allCases) : selectedVerticals

        var sections: [Section] = []
        for vertical in ExploreVertical.allCases.sorted(by: { $0.order < $1.order }) {
            guard verticals.contains(vertical) else { continue }
            let matches = items.filter { item in
                guard item.vertical == vertical else { return false }
                guard !query.isEmpty else { return true }
                return item.title.lowercased().contains(query)
                    || (item.subtitle?.lowercased().contains(query) ?? false)
                    || (item.excerpt?.lowercased().contains(query) ?? false)
            }
            if !matches.isEmpty { sections.append(Section(vertical: vertical, items: matches)) }
        }
        return sections
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

// MARK: - Poster Card (music / sermons / movies / events)

fileprivate struct ExplorePosterCard: View {
    let item: ExploreItem
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                ExploreThumb(url: item.thumbnailURL, icon: item.vertical.icon)
                    .frame(width: 160, height: 108)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                Text(item.title)
                    .font(.coUI(13, weight: .semibold))
                    .foregroundColor(.coInk)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if let subtitle = item.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.coUI(11))
                        .foregroundColor(.coInkTertiary)
                        .lineLimit(1)
                }
            }
            .frame(width: 160, alignment: .leading)
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
