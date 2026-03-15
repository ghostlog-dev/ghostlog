import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    @State private var searchRoots: [String] = Config.shared.load()?.effectiveSearchRoots ?? []
    @State private var hookInstalled: Bool = false
    @State private var loginItemEnabled: Bool = false
    @State private var hideDockIcon: Bool = false
    @State private var saved: Bool = false

    private let hookManager = GitHookManager()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Instellingen").font(.headline)
                Spacer()
                if saved {
                    Label("Opgeslagen", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.callout)
                        .transition(.opacity)
                }
                Button("Opslaan") { save() }
                    .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 12)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

                    // MARK: Verbinding

                    SettingsSectionHeader("Verbinding")

                    SettingsRow {
                        HStack {
                            Text("API URL").foregroundStyle(.secondary)
                            Spacer()
                            Text(GhostlogURLs.api)
                                .foregroundStyle(.secondary)
                                .font(.system(.caption, design: .monospaced))
                                .lineLimit(1)
                        }
                    }

                    SettingsDivider()

                    SettingsRow {
                        HStack {
                            Text("Token").foregroundStyle(.secondary)
                            Spacer()
                            Text(maskedToken)
                                .foregroundStyle(.secondary)
                                .font(.system(.body, design: .monospaced))
                        }
                    }

                    // MARK: Projectmappen

                    SettingsSectionHeader("Projectmappen").padding(.top, 20)

                    if searchRoots.isEmpty {
                        SettingsRow {
                            Text("Nog geen mappen toegevoegd")
                                .foregroundStyle(.tertiary)
                                .font(.callout)
                        }
                    } else {
                        ForEach(Array(searchRoots.enumerated()), id: \.element) { idx, root in
                            if idx > 0 { SettingsDivider() }
                            SettingsRow {
                                HStack {
                                    Text(root)
                                        .font(.system(.caption, design: .monospaced))
                                        .lineLimit(1)
                                    Spacer()
                                    Button(action: { searchRoots.removeAll { $0 == root } }) {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundColor(.red)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    SettingsDivider()

                    SettingsRow {
                        Button {
                            let panel = NSOpenPanel()
                            panel.canChooseDirectories = true
                            panel.canChooseFiles = false
                            if panel.runModal() == .OK, let url = panel.url {
                                if !searchRoots.contains(url.path) { searchRoots.append(url.path) }
                            }
                        } label: {
                            Label("Map toevoegen", systemImage: "plus")
                                .font(.callout)
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.accentColor)
                    }

                    // MARK: Integraties

                    SettingsSectionHeader("Integraties").padding(.top, 20)

                    SettingsRow {
                        Toggle("Git hook (post-commit)", isOn: $hookInstalled)
                            .onChange(of: hookInstalled) { enabled in
                                if enabled {
                                    try? hookManager.install()
                                } else {
                                    hookManager.uninstall()
                                }
                            }
                    }

                    SettingsDivider()

                    SettingsRow {
                        Toggle("Starten bij inloggen", isOn: $loginItemEnabled)
                            .onChange(of: loginItemEnabled) { enabled in
                                if enabled {
                                    try? SMAppService.mainApp.register()
                                } else {
                                    try? SMAppService.mainApp.unregister()
                                }
                            }
                    }

                    // MARK: Uiterlijk

                    SettingsSectionHeader("Uiterlijk").padding(.top, 20)

                    SettingsRow {
                        Toggle("Verberg Dock-icoon", isOn: $hideDockIcon)
                            .onChange(of: hideDockIcon) { hide in
                                NSApp.setActivationPolicy(hide ? .accessory : .regular)
                                if !hide { NSApp.activate(ignoringOtherApps: true) }
                                var config = Config.shared.load() ?? GhostlogConfig()
                                config.hideDockIcon = hide
                                try? Config.shared.save(config)
                            }
                    }
                }
                .padding(.vertical, 8)

                // MARK: Versie

                if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
                    Text("Ghostlog \(version)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 12)
                }
            }
        }
        .onAppear { loadCurrentValues() }
    }

    // MARK: - Helpers

    private var maskedToken: String {
        let token = Config.shared.token ?? ""
        guard token.count > 8 else { return "•••••••" }
        return String(token.prefix(4)) + "•••••••" + String(token.suffix(4))
    }

    private func loadCurrentValues() {
        if let config = Config.shared.load() {
            searchRoots = config.effectiveSearchRoots
        }
        hookInstalled    = hookManager.isInstalled
        loginItemEnabled = SMAppService.mainApp.status == .enabled
        hideDockIcon     = Config.shared.load()?.hideDockIcon ?? false
    }

    private func save() {
        let config = GhostlogConfig(searchRoots: searchRoots)
        try? Config.shared.save(config)
        saved = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { saved = false }
    }
}

// MARK: - Shared components

private struct SettingsSectionHeader: View {
    let title: String
    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title.uppercased())
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 6)
    }
}

private struct SettingsRow<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(Color(red: 22/255, green: 22/255, blue: 22/255))
    }
}

private struct SettingsDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, 16)
    }
}
