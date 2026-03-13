import Foundation
import Combine

final class AppCoordinator: ObservableObject {
    static let shared = AppCoordinator()

    @Published var isConfigured: Bool = false

    private let scheduler    = TrackingScheduler()
    private let heartbeatSvc = HeartbeatService()
    private let buffer       = OfflineBuffer()
    private let appState     = AppState.shared

    init() {
        isConfigured = Config.shared.isConfigured
        if isConfigured { startTracking() }
    }

    func configured() {
        isConfigured = true
        startTracking()
    }

    private func startTracking() {
        let roots = Config.shared.load()?.effectiveSearchRoots ?? []

        scheduler.onHeartbeat = { [weak self] heartbeat in
            guard let self, let token = Config.shared.token else { return }
            let result = await self.heartbeatSvc.send(heartbeat, apiUrl: GhostlogURLs.api, token: token)
            switch result {
            case .success(let r):
                await self.appState.recordActivity(projectName: r.projectName, issueIdentifier: r.issueIdentifier)
                let buffered = self.buffer.read()
                if !buffered.isEmpty {
                    if await self.heartbeatSvc.sendBatch(buffered, apiUrl: GhostlogURLs.api, token: token) {
                        self.buffer.clear()
                    }
                }
            case .unauthorized:
                Config.shared.clearToken()
                await self.appState.recordUnauthenticated()
                Task { @MainActor in self.isConfigured = false }
            case .failure:
                self.buffer.append(heartbeat)
                await self.appState.recordOffline()
            }
        }

        scheduler.onIdle = { [weak self] in
            Task { @MainActor in self?.appState.recordIdle() }
        }

        scheduler.start(searchRoots: roots)
    }
}
