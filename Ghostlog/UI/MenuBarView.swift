import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 0) {
            // Header — huidig project + status
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    Text(appState.currentProject ?? "Geen project")
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    Spacer()
                    Text(appState.todayFormatted)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                if let issue = appState.currentIssue {
                    Text(issue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 10)

            // Per-project breakdown (alleen tonen als er data is)
            if !appState.projectSeconds.isEmpty {
                Divider().padding(.horizontal, 8)

                VStack(spacing: 4) {
                    ForEach(appState.projectSeconds, id: \.name) { entry in
                        ProjectTimeRow(
                            name: entry.name,
                            seconds: entry.seconds,
                            total: appState.totalSeconds,
                            formatFn: appState.format
                        )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }

            Divider().padding(.horizontal, 8)

            VStack(spacing: 1) {
                MenuBarButton("Open Ghostlog", icon: "sidebar.left") {
                    WindowManager.shared.open()
                }
                MenuBarButton("Dashboard", icon: "globe") {
                    if let url = URL(string: GhostlogURLs.web) {
                        openURL(url)
                    }
                }
                MenuBarButton("Instellingen", icon: "gear") {
                    WindowManager.shared.openSettings()
                }
            }
            .padding(.horizontal, 4)
            .padding(.top, 4)

            Divider()
                .padding(.horizontal, 8)
                .padding(.top, 4)

            VStack(spacing: 1) {
                MenuBarButton("Afsluiten", icon: "power") {
                    NSApp.terminate(nil)
                }
            }
            .padding(.horizontal, 4)
            .padding(.top, 4)
            .padding(.bottom, 4)
        }
        .frame(width: 240)
    }

    private var statusColor: Color {
        if appState.isIdle    { return .orange }
        if appState.isOffline { return .red }
        if appState.currentProject != nil { return .green }
        return Color(nsColor: .secondaryLabelColor)
    }
}

private struct ProjectTimeRow: View {
    let name: String
    let seconds: Int
    let total: Int
    let formatFn: (Int) -> String

    private var fraction: Double {
        total > 0 ? Double(seconds) / Double(total) : 0
    }

    var body: some View {
        VStack(spacing: 2) {
            HStack {
                Text(name)
                    .font(.caption)
                    .lineLimit(1)
                Spacer()
                Text(formatFn(seconds))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(nsColor: .separatorColor))
                        .frame(height: 3)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.accentColor)
                        .frame(width: geo.size.width * fraction, height: 3)
                }
            }
            .frame(height: 3)
        }
    }
}

private struct MenuBarButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    @State private var isHovered = false

    init(_ title: String, icon: String, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(isHovered ? Color.accentColor.opacity(0.15) : .clear, in: RoundedRectangle(cornerRadius: 5))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
