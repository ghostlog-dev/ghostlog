import Foundation

private struct TrackingState: Equatable {
    let appName: String
    let windowTitle: String
    let ideProject: String?
    let gitRemote: String?
    let gitBranch: String?
    let browserUrl: String?
}

final class TrackingScheduler {
    private var timer: Timer?
    private var previousState: TrackingState?
    private var lastSentAt: Date?
    private let keepaliveInterval: TimeInterval = 60
    private let builder = HeartbeatBuilder()

    /// Called on main thread with a ready-to-send heartbeat.
    var onHeartbeat: ((Heartbeat) async -> Void)?
    /// Called when idle state is detected.
    var onIdle: (() -> Void)?

    func start(searchRoots: [String], idleThreshold: Double = 300) {
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.tick(searchRoots: searchRoots, idleThreshold: idleThreshold)
            }
        }
        timer?.fire()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    @MainActor
    private func tick(searchRoots: [String], idleThreshold: Double) async {
#if DEBUG
        print("[Scheduler] tick — building heartbeat")
#endif
        // Run off main thread: browser URL detection (osascript / AXUIElement) blocks otherwise
        let heartbeat = await Task.detached(priority: .utility) { [builder] in
            builder.build(searchRoots: searchRoots, idleThreshold: idleThreshold)
        }.value
        guard let heartbeat else {
#if DEBUG
            print("[Scheduler] heartbeat=nil (idle or no active window)")
#endif
            onIdle?()
            return
        }

        let current = TrackingState(
            appName: heartbeat.appName,
            windowTitle: heartbeat.windowTitle,
            ideProject: heartbeat.ideProject,
            gitRemote: heartbeat.gitRemote,
            gitBranch: heartbeat.gitBranch,
            browserUrl: heartbeat.browserUrl
        )

        let now = Date()
        let needsKeepalive = lastSentAt.map { now.timeIntervalSince($0) >= keepaliveInterval } ?? true

        guard current != previousState || needsKeepalive else {
#if DEBUG
            print("[Scheduler] skipped (same state, no keepalive needed)")
#endif
            return
        }

#if DEBUG
        print("[Scheduler] sending heartbeat for \(heartbeat.appName)")
#endif
        previousState = current
        lastSentAt = now
        await onHeartbeat?(heartbeat)
    }
}
