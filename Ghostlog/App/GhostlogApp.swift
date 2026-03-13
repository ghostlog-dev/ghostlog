import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if Config.shared.load()?.hideDockIcon == true {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        WindowManager.shared.open()
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first, url.scheme == "ghostlog" else { return }
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let token = components.queryItems?.first(where: { $0.name == "token" })?.value,
              !token.isEmpty else { return }

        // Require that an auth flow was initiated and the state nonce matches.
        guard let expectedState = AppState.shared.pendingAuthState,
              let receivedState = components.queryItems?.first(where: { $0.name == "state" })?.value,
              receivedState == expectedState else { return }
        AppState.shared.pendingAuthState = nil

        Config.shared.token = token

        DispatchQueue.main.async {
            AppCoordinator.shared.configured()
            AppState.shared.isUnauthenticated = false
        }
    }
}

@main
struct GhostlogApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState     = AppState.shared
    @StateObject private var coordinator  = AppCoordinator.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarRootView()
                .environmentObject(appState)
                .environmentObject(coordinator)
        } label: {
            MenuBarLabel().environmentObject(appState)
        }
        .menuBarExtraStyle(.window)

        Window("Ghostlog instellen", id: "onboarding") {
            OnboardingView()
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)

    }
}
