import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            if let screen = debugScreen {
                debugDestination(screen)
            } else if !appState.hasOnboarded {
                OnboardingView()
            } else if !appState.isAuthenticated {
                // Returning user with no active session (e.g. signed out, or
                // a stale/missing session at launch). There is no anonymous
                // fallback, so this gate is mandatory and non-dismissible.
                AuthGateView()
            } else {
                MainTabView()
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

            if !appState.tabBarHidden {
                COTabBar(selection: $appState.selectedTab)
                    .transition(
                        .asymmetric(
                            insertion: .opacity,
                            removal: .opacity.combined(with: .offset(y: 80))
                        )
                    )
            }
        }
        .animation(.easeInOut(duration: 0.2), value: appState.tabBarHidden)
    }
}

// MARK: - Mandatory Auth Gate

/// Full-screen, non-dismissible sign-in gate shown when a previously
/// onboarded user has no active Supabase session (most commonly right after
/// they sign out). Reuses AuthSheet's Apple + email UI directly in the view
/// hierarchy (not as a `.sheet`), so there is no swipe-to-dismiss and no
/// "skip" affordance — a real account is required to reach MainTabView.
struct AuthGateView: View {
    @EnvironmentObject private var appState: AppState
    @State private var mode: AuthMode = .signIn

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 20)
            AuthSheet(mode: mode) {
                appState.refreshAuthState()
            }
            modeToggle
        }
        .background(Color.coPaper.ignoresSafeArea())
    }

    private var modeToggle: some View {
        Button {
            mode = (mode == .signIn) ? .createAccount : .signIn
        } label: {
            Text(mode == .signIn ? "Need an account? Create one" : "Already have an account? Sign in")
                .font(.coUI(13))
                .foregroundColor(.coInkSecondary)
        }
        .padding(.bottom, 24)
    }
}

// MARK: - Hides Tab Bar Modifier

/// Applied to pushed detail screens (Kyra, the pushed Bible reader, etc.) so
/// the floating COTabBar in MainTabView's ZStack gets out of the way while
/// that screen is on-screen — otherwise its bottom bars/toolbars render
/// underneath the tab bar and become untappable.
struct HidesTabBar: ViewModifier {
    @EnvironmentObject private var appState: AppState

    func body(content: Content) -> some View {
        content
            .onAppear { appState.tabBarHidden = true }
            .onDisappear { appState.tabBarHidden = false }
    }
}

extension View {
    func hidesTabBar() -> some View {
        modifier(HidesTabBar())
    }
}

// MARK: - Interactive Swipe-Back

/// `navigationBarBackButtonHidden(true)` (used by several custom-chevron
/// screens in this app) disables UIKit's interactive edge-swipe-to-pop
/// gesture as a side effect. Restoring the gesture's delegate here brings
/// swipe-back back for every navigation controller in the app.
extension UINavigationController: UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
    }
}
