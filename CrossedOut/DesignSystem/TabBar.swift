import SwiftUI

// MARK: - Tabs

enum COTab: String, CaseIterable, Identifiable {
    case today, bible, community, attend, more

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: return "Today"
        case .bible: return "Bible"
        case .community: return "Community"
        case .attend: return "Attend"
        case .more: return "More"
        }
    }

    var icon: COIconName {
        switch self {
        case .today: return .today
        case .bible: return .bible
        case .community: return .community
        case .attend: return .attend
        case .more: return .more
        }
    }
}

// MARK: - Custom Tab Bar

struct COTabBar: View {
    @Binding var selection: COTab

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.coDivider)
                .frame(height: 1)
            HStack(spacing: 0) {
                ForEach(COTab.allCases) { tab in
                    Button {
                        selection = tab
                    } label: {
                        VStack(spacing: 4) {
                            COIcon(tab.icon, size: 22,
                                   color: selection == tab ? .coCrossRed : .coInkTertiary)
                            Text(tab.title)
                                .font(.coUI(10, weight: selection == tab ? .semibold : .regular))
                                .foregroundColor(selection == tab ? .coCrossRed : .coInkTertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(height: 54)
            .padding(.top, 2)
        }
        .background(Color.coPaper.ignoresSafeArea(edges: .bottom))
    }
}
