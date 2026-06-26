import SwiftUI
import FirebaseCore

@main
struct Mansion_NightclubApp: App {
    @StateObject private var appState = AppState()

    init() {
        FirebaseApp.configure()
        OneSignalManager.shared.initialize()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .onChange(of: appState.currentUser?.id) { _, _ in
                    // OneSignal login deferred — device must have a subscription ID first
                }
        }
    }
}
