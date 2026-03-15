import Foundation
import OSLog

private let logger = Logger(subsystem: "com.ghostlog.app", category: "Heartbeat")

final class HeartbeatBuilder {
    private let windowTracker  = WindowTracker()
    private let idleTracker    = IdleTracker()
    private let gitTracker     = GitTracker()
    private let browserTracker = BrowserURLTracker()

    // Lowercase for case-insensitive matching
    private let browserApps: Set<String> = [
        "google chrome", "firefox", "firefox developer edition", "firefox nightly",
        "safari", "safari technology preview", "arc", "brave browser",
        "zen browser", "zen", "microsoft edge", "chromium", "vivaldi", "opera",
    ]

    /// Returns nil when idle — caller should skip sending.
    func build(searchRoots: [String], idleThreshold: Double = 300) -> Heartbeat? {
        let idle = idleTracker.idleSeconds()
        guard idle < idleThreshold else {
            logger.debug("⏸ idle=\(idle, format: .fixed(precision: 0))s — skipping")
            return nil
        }

        guard let window = windowTracker.activeWindow() else {
            logger.debug("⏸ no active window")
            return nil
        }

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

        let isBrowser = browserApps.contains(window.appName.lowercased())
        let browserUrl = isBrowser
            ? browserTracker.currentURL(appName: window.appName, pid: window.pid)
            : nil

        let entry = """
            app          : \(window.appName)
            window_title : \(window.windowTitle)
            ide_project  : \(ideProject ?? "–")
            git_remote   : \(gitRemote ?? "–")
            git_branch   : \(gitBranch ?? "–")
            browser_url  : \(browserUrl ?? (isBrowser ? "⚠️ browser detected but no URL" : "–"))
            """
        logger.info("\(entry)")
        Task { @MainActor in DebugLog.shared.append(entry) }

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
