import SwiftUI

struct MoreHubView: View {
    private struct Row: Identifiable {
        let id = UUID()
        let title: String
        let icon: COIconName
    }

    private let rows: [Row] = [
        Row(title: "Explore", icon: .search),
        Row(title: "Church Finder", icon: .mapPin),
        Row(title: "Give", icon: .give),
        Row(title: "Journey", icon: .flame),
        Row(title: "Kyra", icon: .prayer)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("More")
                        .font(.coDisplay(28, weight: .semibold))
                        .foregroundColor(.coInk)
                        .padding(.top, 8)

                    VStack(spacing: 0) {
                        ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                            NavigationLink { destination(for: row.title) } label: {
                                rowLabel(row)
                            }
                            .buttonStyle(.plain)
                            if index < rows.count - 1 { CODivider() }
                        }
                    }
                    .padding(.horizontal, 4)
                    .background(Color.coCard)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.coDivider, lineWidth: 1)
                    )
                    .coShadow(cornerRadius: 14)

                    Spacer(minLength: 80)
                }
                .padding(.horizontal, 22)
            }
            .background(Color.coPaper.ignoresSafeArea())
        }
    }

    @ViewBuilder
    private func rowLabel(_ row: Row) -> some View {
        HStack(spacing: 14) {
            COIcon(row.icon, size: 22, color: .coInkSecondary)
            Text(row.title)
                .font(.coUI(16))
                .foregroundColor(.coInk)
            Spacer()
            COIcon(.chevronRight, size: 16, color: .coInkTertiary)
        }
        .padding(.vertical, 15)
        .padding(.horizontal, 12)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func destination(for title: String) -> some View {
        switch title {
        case "Explore": ExploreView()
        case "Church Finder": ChurchFinderView()
        case "Give": GiveView()
        case "Journey": JourneyProgressView()
        case "Kyra": KyraView()
        default: ExploreView()
        }
    }
}
