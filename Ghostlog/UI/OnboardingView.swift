import SwiftUI
import ServiceManagement

struct OnboardingView: View {
    @State private var step: Int = 1
    @State private var searchRoots: [String] = GhostlogConfig(searchRoots: nil).effectiveSearchRoots
    @State private var isWaitingForBrowser: Bool = false
    var sessionExpired: Bool = false
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var coordinator = AppCoordinator.shared

    var body: some View {
        VStack(spacing: 20) {
            Text("Ghostlog instellen")
                .font(.title2).fontWeight(.semibold)

            if step == 1 {
                connectionStep
            } else {
                rootsStep
            }
        }
        .padding(24)
        .frame(width: 360)
        .onChange(of: coordinator.isConfigured) { isConfigured in
            if isConfigured { dismiss() }
        }
    }

    // MARK: Step 1 — Connection
    private var connectionStep: some View {
        VStack(spacing: 16) {
            if sessionExpired {
                Text("Je sessie is verlopen.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Text("Ghostlog heeft toegang nodig tot je account.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button(isWaitingForBrowser ? "Wachten op browser..." : "Inloggen via browser") {
                openInBrowser()
            }
            .buttonStyle(.borderedProminent)
            .disabled(isWaitingForBrowser)

            if isWaitingForBrowser {
                Button("Annuleren") { isWaitingForBrowser = false }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Step 2 — Project Roots
    private var rootsStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Projectmappen").font(.headline)
            Text("Ghostlog zoekt hier naar je projecten om git informatie uit te lezen.")
                .font(.caption).foregroundColor(.secondary)

            List {
                ForEach(searchRoots, id: \.self) { root in
                    HStack {
                        Text(root).font(.system(.body, design: .monospaced))
                        Spacer()
                        Button(action: { searchRoots.removeAll { $0 == root } }) {
                            Image(systemName: "minus.circle.fill").foregroundColor(.red)
                        }.buttonStyle(.plain)
                    }
                }
            }
            .frame(height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            Button("Map toevoegen") {
                let panel = NSOpenPanel()
                panel.canChooseDirectories = true
                panel.canChooseFiles = false
                panel.allowsMultipleSelection = false
                if panel.runModal() == .OK, let url = panel.url {
                    if !searchRoots.contains(url.path) {
                        searchRoots.append(url.path)
                    }
                }
            }

            HStack {
                Spacer()
                Button("Klaar") { saveAndFinish() }
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    private func openInBrowser() {
        let state = UUID().uuidString
        AppState.shared.pendingAuthState = state

        var callbackComponents = URLComponents(string: "ghostlog://auth/callback")!
        callbackComponents.queryItems = [URLQueryItem(name: "state", value: state)]
        guard let callbackUrl = callbackComponents.url else { return }

        var components = URLComponents(string: GhostlogURLs.web + "/auth/device")!
        components.queryItems = [URLQueryItem(name: "callback", value: callbackUrl.absoluteString)]
        guard let url = components.url else { return }

        isWaitingForBrowser = true
        NSWorkspace.shared.open(url)
    }

    private func saveAndFinish() {
        var config = Config.shared.load() ?? GhostlogConfig()
        config.searchRoots = searchRoots
        try? Config.shared.save(config)
        AppCoordinator.shared.configured()
        dismiss()
    }
}
