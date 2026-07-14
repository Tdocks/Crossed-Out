import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            if let screen = debugScreen {
                debugDestination(screen)
            } else if appState.hasOnboarded {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .task { await appState.bootstrap() }
    }

    // MARK: Debug screen override (screenshot verification)
    private var debugScreen: String? {
        ProcessInfo.processInfo.environment["CO_SCREEN"]
    }

    @ViewBuilder
    private func debugDestination(_ screen: String) -> some View {
        ZStack(alignment: .bottom) {
            Color.coPaper.ignoresSafeArea()
            switch screen {
            case "today": MainTabView().onAppear { appState.hasOnboarded = true; appState.selectedTab = .today }
            case "bible": MainTabView().onAppear { appState.hasOnboarded = true; appState.selectedTab = .bible }
            case "community": MainTabView().onAppear { appState.hasOnboarded = true; appState.selectedTab = .community }
            case "attend": MainTabView().onAppear { appState.hasOnboarded = true; appState.selectedTab = .attend }
            case "more": MainTabView().onAppear { appState.hasOnboarded = true; appState.selectedTab = .more }
            case "kyra": NavigationStack { KyraView() }
            case "progress": NavigationStack { JourneyProgressView() }
            case "bridge": NavigationStack { BridgeShareView() }
            case "explore": NavigationStack { ExploreView() }
            case "churches": NavigationStack { ChurchFinderView() }
            case "give": NavigationStack { GiveView() }
            case "settings": NavigationStack { SettingsView() }
            default: OnboardingView()
            }
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.coPaper.ignoresSafeArea()

            Group {
                switch appState.selectedTab {
                case .today: TodayView()
                case .bible: BibleReaderView()
                case .community: CommunityView()
                case .attend: AttendView()
                case .more: MoreHubView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            COTabBar(selection: $appState.selectedTab)
        }
    }
}
