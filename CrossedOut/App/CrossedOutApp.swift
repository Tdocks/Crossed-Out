import SwiftUI

@main
struct CrossedOutApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .tint(.coCrossRed)
                .onAppear {
                    #if DEBUG
                    Typography.debugPrintFonts()
                    #endif
                }
        }
    }
}
