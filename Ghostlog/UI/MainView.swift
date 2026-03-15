import SwiftUI

enum MainTab {
    case today, reports, projects, rules, team, settings
}

struct MainView: View {
    @EnvironmentObject var windowState: MainWindowState
    @StateObject private var userState = UserState.shared

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            VStack(spacing: 2) {
                // Team header — always reserve space to prevent layout shift on load
                TeamHeader(
                    teamName: userState.currentTeamName ?? "",
                    user: userState.user,
                    hasMultiple: userState.hasMultipleTeams
                )
                .padding(.bottom, 12)
                .opacity(userState.currentTeamName != nil ? 1 : 0)

                SidebarButton(title: "Vandaag",      icon: "clock",        tab: .today,    current: $windowState.tab)
                SidebarButton(title: "Rapportage",   icon: "chart.bar",    tab: .reports,  current: $windowState.tab)

                Divider().padding(.vertical, 4).padding(.horizontal, 8)

                SidebarButton(title: "Projecten",    icon: "folder",       tab: .projects, current: $windowState.tab)
                SidebarButton(title: "Regels",       icon: "wand.and.rays",tab: .rules,    current: $windowState.tab)
                SidebarButton(title: "Team",         icon: "person.3",     tab: .team,     current: $windowState.tab)

                Spacer()

                Divider().padding(.horizontal, 8).padding(.bottom, 4)
                SidebarButton(title: "Instellingen", icon: "gear",         tab: .settings, current: $windowState.tab)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .frame(width: 168)
            .background(Color(red: 12/255, green: 12/255, blue: 12/255))

            Divider()

            // Content
            Group {
                switch windowState.tab {
                case .today:    TodayView()
                case .reports:  ReportsView()
                case .projects: ProjectsView()
                case .rules:    RulesView()
                case .team:     TeamView()
                case .settings: SettingsView().environmentObject(AppState.shared)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 740, height: 560)
        .background(Color(red: 16/255, green: 16/255, blue: 16/255))
        .preferredColorScheme(.dark)
        .onAppear { userState.load() }
    }
}

// MARK: - Team header

private struct TeamHeader: View {
    let teamName: String
    let user: GhostlogUser?
    let hasMultiple: Bool
    @State private var showPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Image(systemName: "building.2").font(.caption).foregroundStyle(.secondary)
                Text(teamName).font(.caption).fontWeight(.medium).lineLimit(1)
                if hasMultiple {
                    Spacer()
                    Button { showPicker = true } label: {
                        Image(systemName: "chevron.up.chevron.down").font(.caption2).foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showPicker) {
                        TeamPickerPopover(user: user) { showPicker = false }
                    }
                }
            }
            if let name = user?.name {
                Text(name).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct TeamPickerPopover: View {
    let user: GhostlogUser?
    let onDismiss: () -> Void

    private var teams: [GhostlogTeam] { user?.teams ?? [] }
    private var currentId: Int { user?.teamId ?? -1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Wissel van team").font(.caption).foregroundStyle(.secondary).padding(.bottom, 2)
            ForEach(teams) { team in
                teamButton(team)
            }
        }
        .padding(12)
        .frame(minWidth: 180)
    }

    private func teamButton(_ team: GhostlogTeam) -> some View {
        Button {
            UserState.shared.switchTeam(id: team.id)
            onDismiss()
        } label: {
            HStack {
                Text(team.name)
                Spacer()
                if team.id == currentId {
                    Image(systemName: "checkmark").foregroundColor(.accentColor)
                }
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 12).padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Sidebar button

private struct SidebarButton: View {
    let title: String
    let icon: String
    let tab: MainTab
    @Binding var current: MainTab

    private var selected: Bool { current == tab }
    @State private var isHovered = false

    var body: some View {
        Button { current = tab } label: {
            HStack(spacing: 8) {
                Image(systemName: icon).frame(width: 16)
                Text(title).font(.callout)
                Spacer()
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(
                selected
                    ? Color.accentColor.opacity(0.15)
                    : isHovered ? Color(nsColor: .separatorColor).opacity(0.5) : Color.clear,
                in: RoundedRectangle(cornerRadius: 7)
            )
            .foregroundStyle(selected ? Color.accentColor : Color.primary)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
