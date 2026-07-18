import SwiftUI

struct MoreHubView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showCreateAccount = false

    private struct Row: Identifiable {
        let id = UUID()
        let title: String
        let icon: COIconName
    }

    private let rows: [Row] = [
        Row(title: "Devotionals", icon: .journal),
        Row(title: "Explore", icon: .search),
        Row(title: "Church Finder", icon: .mapPin),
        Row(title: "Give", icon: .give),
        Row(title: "Journey", icon: .flame),
        Row(title: "Kyra", icon: .prayer),
        Row(title: "Settings", icon: .more)
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

                    accountSection

                    Spacer(minLength: 80)
                }
                .padding(.horizontal, 22)
            }
            .background(Color.coPaper.ignoresSafeArea())
            .sheet(isPresented: $showCreateAccount) {
                AuthSheet(mode: .createAccount) { _ in
                    appState.refreshAfterAuth()
                }
            }
        }
    }

    // MARK: - Account

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ACCOUNT")
                .font(.coUI(11, weight: .medium))
                .foregroundColor(.coInkTertiary)
                .tracking(1.2)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                if let email = SupabaseService.shared.currentUserEmail {
                    HStack(spacing: 14) {
                        COIcon(.community, size: 20, color: .coInkSecondary)
                        Text(email)
                            .font(.coUI(13))
                            .foregroundColor(.coInkSecondary)
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 12)
                    CODivider()
                    Button {
                        appState.signOutAndReset()
                    } label: {
                        HStack {
                            Text("Sign Out")
                                .font(.coUI(15))
                                .foregroundColor(.coCrossRed)
                            Spacer()
                        }
                        .padding(.vertical, 14)
                        .padding(.horizontal, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        showCreateAccount = true
                    } label: {
                        HStack(spacing: 14) {
                            COIcon(.community, size: 20, color: .coInkSecondary)
                            Text("Create Account")
                                .font(.coUI(16))
                                .foregroundColor(.coInk)
                            Spacer()
                            COIcon(.chevronRight, size: 16, color: .coInkTertiary)
                        }
                        .padding(.vertical, 15)
                        .padding(.horizontal, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
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
        case "Devotionals": DevotionalsHubView()
        case "Explore": ExploreView()
        case "Church Finder": ChurchFinderView()
        case "Give": GiveView()
        case "Journey": JourneyProgressView()
        case "Kyra": KyraView()
        case "Settings": SettingsView()
        default: ExploreView()
        }
    }
}
