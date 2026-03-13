import Foundation
import Combine

final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var currentProject: String? = nil
    @Published var currentIssue: String?   = nil
    @Published var isIdle: Bool            = false
    @Published var isOffline: Bool         = false
    @Published var isUnauthenticated: Bool = false

    /// Nonce used to verify the ghostlog:// auth callback — prevents URL scheme hijacking.
    var pendingAuthState: String? = nil

    @Published var totalSeconds: Int = 0
    @Published var projectSeconds: [(name: String, seconds: Int)] = []

    private var lastActiveAt: Date? = nil
    private let store = DayStore.shared

    init() {
        totalSeconds   = store.totalSeconds
        projectSeconds = store.projectSeconds
    }

    var todayFormatted: String {
        format(seconds: totalSeconds)
    }

    func format(seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        return h > 0 ? "\(h)u \(m)m" : "\(m)m"
    }

    @MainActor
    func recordActivity(projectName: String?, issueIdentifier: String?) {
        let now = Date()
        if let last = lastActiveAt {
            let elapsed = Int(now.timeIntervalSince(last))
            if elapsed <= 120 {
                store.add(seconds: elapsed, project: projectName ?? currentProject)
                totalSeconds   = store.totalSeconds
                projectSeconds = store.projectSeconds
            }
        }
        lastActiveAt   = now
        currentProject = projectName
        currentIssue   = issueIdentifier
        isIdle         = false
        isOffline      = false
    }

    @MainActor
    func recordIdle() {
        isIdle       = true
        lastActiveAt = nil
    }

    @MainActor
    func recordOffline() {
        isOffline = true
    }

    @MainActor
    func recordUnauthenticated() {
        isUnauthenticated = true
        isIdle            = false
        isOffline         = false
        currentProject    = nil
    }
}
