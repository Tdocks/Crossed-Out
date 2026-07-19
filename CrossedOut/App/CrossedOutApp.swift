import SwiftUI

@main
struct CrossedOutApp: App {
    @StateObject private var appState = AppState()
    @AppStorage("co.appearance") private var appearanceRaw: String = COAppearance.system.rawValue

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(SubscriptionService.shared)
                .tint(.coCrossRed)
                .preferredColorScheme(COAppearance(rawValue: appearanceRaw)?.colorScheme)
                .task {
                    AnalyticsService.shared.start()
                    await SubscriptionService.shared.start()
                    appState.refreshPlusFromSubscriptions()
                }
                .onAppear {
                    #if DEBUG
                    Typography.debugPrintFonts()
                    #endif
                }
        }
    }
}
