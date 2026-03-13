import Foundation

enum GhostlogURLs {
    static let api = "https://api.ghostlog.nl"
    static let web = "https://ghostlog.nl"
}

struct GhostlogConfig: Codable {
    var searchRoots: [String]?
    var hideDockIcon: Bool?

    var effectiveSearchRoots: [String] {
        if let roots = searchRoots, !roots.isEmpty { return roots }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "\(home)/Documents/projects",
            "\(home)/projects",
            "\(home)/Sites",
            "\(home)/Herd",
            "\(home)/Developer",
        ].filter { FileManager.default.fileExists(atPath: $0) }
    }
}

/// Legacy config shape — used only for one-time migration of stored token.
private struct LegacyGhostlogConfig: Decodable {
    var token: String?
    var searchRoots: [String]?
}

final class Config {
    static let shared = Config()

    private let configPath: URL
    private let keychainService: String

    /// Token is stored in the macOS Keychain, never on disk.
    var token: String? {
        get { KeychainHelper.loadToken(service: keychainService) }
        set {
            if let t = newValue, !t.isEmpty {
                KeychainHelper.saveToken(t, service: keychainService)
            } else {
                KeychainHelper.deleteToken(service: keychainService)
            }
        }
    }

    var isConfigured: Bool {
        token != nil
    }

    init(directory: URL? = nil, keychainService: String = "com.ghostlog.app") {
        self.keychainService = keychainService
        let dir = directory ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".timetracking")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        configPath = dir.appendingPathComponent("config.json")
        migrateTokenIfNeeded()
    }

    func load() -> GhostlogConfig? {
        guard let data = try? Data(contentsOf: configPath) else { return GhostlogConfig() }
        return try? JSONDecoder().decode(GhostlogConfig.self, from: data)
    }

    func save(_ config: GhostlogConfig) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        try data.write(to: configPath, options: .atomic)
    }

    func clearToken() {
        KeychainHelper.deleteToken(service: keychainService)
    }

    // MARK: - Migration

    private func migrateTokenIfNeeded() {
        guard KeychainHelper.loadToken(service: keychainService) == nil,
              let data = try? Data(contentsOf: configPath),
              let legacy = try? JSONDecoder().decode(LegacyGhostlogConfig.self, from: data),
              let legacyToken = legacy.token, !legacyToken.isEmpty else { return }

        KeychainHelper.saveToken(legacyToken)

        // Rewrite config.json without the token field
        let clean = GhostlogConfig(searchRoots: legacy.searchRoots)
        try? save(clean)
    }
}
