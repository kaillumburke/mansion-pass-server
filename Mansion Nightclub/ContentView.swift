import SwiftUI
#if canImport(OneSignalFramework)
import OneSignalFramework
#endif

struct RootView: View {
    @EnvironmentObject var appState: AppState
    @State private var showSplash = true
    @State private var showOneSignalAlert = false
    // Held strongly so ARC doesn't drop it
    @State private var pushObserver: PushSubscriptionObserver?

    var body: some View {
        ZStack {
            if showSplash || appState.isLoading {
                SplashView()
                    .transition(.opacity)
            } else if appState.isAuthenticated {
                MainTabView()
                    .transition(.opacity)
            } else {
                LandingView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: appState.isAuthenticated)
        .animation(.easeInOut(duration: 0.4), value: showSplash)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                showSplash = false
            }
            registerPushObserver()
            // Request after a short delay so the UI is fully visible
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                OneSignalManager.shared.requestPermission()
            }
        }
        .alert("Push notifications enabled", isPresented: $showOneSignalAlert) {
            Button("Got it") { }
        } message: {
            Text("You'll receive updates about upcoming events and exclusive offers from Mansion Liverpool.")
        }
    }

    private func registerPushObserver() {
        #if canImport(OneSignalFramework)
        let observer = PushSubscriptionObserver {
            showOneSignalAlert = true
        }
        pushObserver = observer
        OneSignal.User.pushSubscription.addObserver(observer)
        #endif
    }
}

// MARK: - Push Subscription Observer

#if canImport(OneSignalFramework)
class PushSubscriptionObserver: NSObject, OSPushSubscriptionObserver {
    private let onSubscribed: () -> Void

    init(onSubscribed: @escaping () -> Void) {
        self.onSubscribed = onSubscribed
    }

    func onPushSubscriptionDidChange(state: OSPushSubscriptionChangedState) {
        let prev = state.previous.id
        guard let curr = state.current.id, !curr.isEmpty else { return }
        // Register every device's subscription ID so REST API can target correctly
        OneSignalConfig.registerSubscriptionId(curr)
        guard prev == nil || prev?.isEmpty == true else { return }
        DispatchQueue.main.async { [weak self] in self?.onSubscribed() }
    }
}
#else
// Stub so the file compiles before the SDK is added
class PushSubscriptionObserver: NSObject {
    init(onSubscribed: @escaping () -> Void) {}
}
#endif
