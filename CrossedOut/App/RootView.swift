import SwiftUI
import UIKit

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
            } else if appState.needsLegalAcceptance {
                // Signed in, but hasn't accepted the current Terms version
                // (account predates the consent flow, or the Terms changed).
                // Non-dismissible; "I Agree" or sign out (migration 0023).
                LegalAcceptanceGateView()
            } else if appState.isPendingVerification {
                // A church that self-signed-up in the app. No app access until
                // a system admin verifies the account (migration 0021).
                PendingVerificationView()
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
            case "plus": PlusPaywallView()
            default: OnboardingView()
            }
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showKyra = false
    // Draggable Kyra bubble: committed offset from its default bottom-trailing
    // anchor, the in-flight drag delta, and a flag that suppresses the tab
    // swipe while the user is repositioning the bubble.
    @State private var kyraOffset: CGSize = .zero
    @State private var kyraDrag: CGSize = .zero
    @State private var kyraDragging = false

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

            // Persistent Kyra access — a floating guide button above the tab
            // bar, available on every tab. Hidden on detail screens. Draggable
            // so it can be moved off buttons it would otherwise cover.
            if !appState.tabBarHidden {
                GeometryReader { geo in
                    kyraBubble(in: geo)
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: appState.tabBarHidden)
        // Swipe left/right anywhere in the tab content to move between tabs.
        // Runs alongside scroll views (simultaneousGesture) and only fires on a
        // decisive, clearly-horizontal swipe, and never while a detail screen has
        // hidden the tab bar (so it can't fight the edge-swipe-back gesture).
        .simultaneousGesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    guard !appState.tabBarHidden, !kyraDragging else { return }
                    let dx = value.translation.width
                    let dy = value.translation.height
                    guard abs(dx) > 60, abs(dx) > abs(dy) * 1.5 else { return }
                    let tabs = COTab.allCases
                    guard let i = tabs.firstIndex(of: appState.selectedTab) else { return }
                    if dx < 0, i < tabs.count - 1 {
                        withAnimation(.easeInOut(duration: 0.2)) { appState.selectedTab = tabs[i + 1] }
                    } else if dx > 0, i > 0, value.startLocation.x > 44 {
                        // Rightward swipe = previous tab — but NOT from the left
                        // edge, which belongs to the navigation back-swipe. This
                        // stops a back gesture inside a pushed screen (e.g.
                        // More -> Journey) from being hijacked into a tab change.
                        withAnimation(.easeInOut(duration: 0.2)) { appState.selectedTab = tabs[i - 1] }
                    }
                }
        )
        // Switching tabs always restores the tab bar — a stranded detail screen
        // can never leave it hidden once the user changes tabs.
        .onChange(of: appState.selectedTab) { _, _ in
            appState.tabBarHidden = false
        }
        .fullScreenCover(isPresented: $showKyra) {
            KyraView().environmentObject(appState)
        }
    }

    // Draggable floating Kyra bubble. A single DragGesture handles both tap
    // (open Kyra) and drag (reposition), disambiguated by distance, so it can
    // be moved off any button it happens to cover. Position is clamped to the
    // safe area and kept clear of the tab bar, and persists for the session.
    private func kyraBubble(in geo: GeometryProxy) -> some View {
        let size: CGFloat = 54
        let margin: CGFloat = 16
        let bottomClearance: CGFloat = 82
        let defaultX = geo.size.width - 20 - size / 2
        let defaultY = geo.size.height - bottomClearance - size / 2
        let minX = margin + size / 2
        let maxX = geo.size.width - margin - size / 2
        let minY = geo.safeAreaInsets.top + margin + size / 2
        let maxY = geo.size.height - bottomClearance - size / 2
        let x = min(max(defaultX + kyraOffset.width + kyraDrag.width, minX), maxX)
        let y = min(max(defaultY + kyraOffset.height + kyraDrag.height, minY), maxY)

        return Text("K")
            .font(.coScripture(22))
            .foregroundColor(.white)
            .frame(width: size, height: size)
            .background(Color.coCrossRed)
            .clipShape(Circle())
            .shadow(color: .black.opacity(0.22), radius: 6, y: 3)
            .position(x: x, y: y)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        if hypot(v.translation.width, v.translation.height) > 6 {
                            kyraDragging = true
                        }
                        kyraDrag = v.translation
                    }
                    .onEnded { v in
                        let moved = hypot(v.translation.width, v.translation.height)
                        if moved < 8 {
                            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                            showKyra = true
                        } else {
                            kyraOffset.width += v.translation.width
                            kyraOffset.height += v.translation.height
                        }
                        kyraDrag = .zero
                        // Reset on the next runloop so the tab-swipe's onEnded,
                        // which fires in the same gesture cycle, still sees the
                        // drag flag and stays suppressed.
                        DispatchQueue.main.async { kyraDragging = false }
                    }
            )
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
            AuthSheet(mode: mode) { _ in
                // Re-runs bootstrap so remote data AND the Terms-acceptance
                // check load for the account that just signed in.
                appState.refreshAfterAuth()
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
extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
    }
}
