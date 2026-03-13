import SwiftUI

struct MenuBarLabel: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
            if let project = appState.currentProject {
                Text(project)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 120)
            }
        }
    }

    private var iconName: String {
        if appState.isOffline { return "clock.badge.exclamationmark" }
        if appState.isIdle    { return "clock" }
        return "clock.fill"
    }
}
