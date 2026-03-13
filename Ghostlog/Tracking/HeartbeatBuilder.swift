import Foundation

final class HeartbeatBuilder {
    private let windowTracker  = WindowTracker()
    private let idleTracker    = IdleTracker()
    private let gitTracker     = GitTracker()
    private let browserTracker = BrowserURLTracker()

    private let browserApps: Set<String> = [
        "Google Chrome", "Firefox", "Firefox Developer Edition", "Firefox Nightly",
        "Safari", "Safari Technology Preview", "Arc", "Brave Browser",
        "Zen Browser", "Zen", "Microsoft Edge", "Chromium", "Vivaldi", "Opera",
    ]

    /// Returns nil when idle — caller should skip sending.
    func build(searchRoots: [String], idleThreshold: Double = 300) -> Heartbeat? {
        let idle = idleTracker.idleSeconds()
        guard idle < idleThreshold else { return nil }

        guard let window = windowTracker.activeWindow() else { return nil }

        let ideProject = IdeProjectExtractor.extract(
            windowTitle: window.windowTitle, appName: window.appName
        )

        var gitRemote: String? = nil
        var gitBranch: String? = nil
        if let project = ideProject,
           let path = gitTracker.resolveProjectPath(basename: project, searchRoots: searchRoots) {
            gitRemote = gitTracker.gitRemote(at: path)
            gitBranch = gitTracker.gitBranch(at: path)
        }

        let browserUrl = browserApps.contains(window.appName)
            ? browserTracker.currentURL(appName: window.appName, pid: window.pid)
            : nil

        return Heartbeat(
            recordedAt: ISO8601DateFormatter().string(from: Date()),
            appName: window.appName,
            windowTitle: window.windowTitle,
            ideProject: ideProject,
            gitRemote: gitRemote,
            gitBranch: gitBranch,
            browserUrl: browserUrl,
            isIdle: false,
            idleSeconds: Int(idle)
        )
    }
}
