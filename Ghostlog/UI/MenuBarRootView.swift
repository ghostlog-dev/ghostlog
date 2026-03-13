import SwiftUI

struct MenuBarRootView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var coordinator: AppCoordinator
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        if coordinator.isConfigured {
            MenuBarView()
        } else {
            unconfiguredView
        }
    }

    private var unconfiguredView: some View {
        VStack(spacing: 12) {
            Text("Ghostlog").font(.headline)
            if appState.isUnauthenticated {
                Text("Sessie verlopen").foregroundStyle(.orange).font(.caption)
            } else {
                Text("Nog niet ingesteld").foregroundColor(.secondary)
            }
            Button("Instellen") {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "onboarding")
            }
        }
        .padding()
        .frame(width: 200)
    }
}
