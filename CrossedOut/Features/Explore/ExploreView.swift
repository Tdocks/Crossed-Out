import SwiftUI

// MARK: - Explore

struct ExploreView: View {
    @State private var searchText: String = ""
    @State private var selectedChips: Set<String> = []

    private let categories = ["Music", "Sermons", "Devotionals", "Movies", "Events"]

    var body: some View {
        ZStack {
            Color.coPaper.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    searchField
                    chipRow
                    recommendedSection
                    musicSection
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
            TextField("Search", text: $searchText)
                .font(.coUI(15))
                .foregroundColor(.coInk)
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
                ForEach(categories, id: \.self) { category in
                    COChip(text: category, selected: selectedChips.contains(category)) {
                        toggle(category)
                    }
                }
            }
        }
    }

    private func toggle(_ category: String) {
        if selectedChips.contains(category) {
            selectedChips.remove(category)
        } else {
            selectedChips.insert(category)
        }
    }

    // MARK: Recommended

    private var recommendedSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            COSectionHeader(title: "Recommended for You")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    RecommendedCard(title: "Overcoming Anxiety — Devotional · The Bible Project", icon: .journal)
                    RecommendedCard(title: "Rest in Him — Worship Playlist", icon: .music)
                }
            }
        }
    }

    // MARK: Music

    private var musicSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            COSectionHeader(title: "Christian Music For You")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(MockData.musicForYou, id: \.self) { title in
                        MusicTile(title: title)
                    }
                }
            }
        }
    }
}

// MARK: - Recommended Card

fileprivate struct RecommendedCard: View {
    let title: String
    let icon: COIconName

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            COPlaceholderBlock(icon: icon, cornerRadius: 0, iconSize: 30)
            VStack(spacing: 0) {
                Spacer()
                LinearGradient(
                    colors: [Color.black.opacity(0.0), Color.black.opacity(0.42)],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 84)
            }
            Text(title)
                .font(.coUI(13, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(2)
                .padding(10)
        }
        .frame(width: 160, height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Music Tile

fileprivate struct MusicTile: View {
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            COPlaceholderBlock(icon: .music, iconSize: 26)
                .frame(width: 120, height: 120)
            Text(title)
                .font(.coUI(13, weight: .medium))
                .foregroundColor(.coInk)
                .lineLimit(1)
            Text("Playlist")
                .font(.coUI(11))
                .foregroundColor(.coInkTertiary)
        }
        .frame(width: 120, alignment: .leading)
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
    ExploreView()
}
