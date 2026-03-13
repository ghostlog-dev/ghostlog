import Foundation

struct Heartbeat: Codable {
    let recordedAt: String
    let appName: String
    let windowTitle: String
    let ideProject: String?
    let gitRemote: String?
    let gitBranch: String?
    let browserUrl: String?
    let isIdle: Bool
    let idleSeconds: Int

    enum CodingKeys: String, CodingKey {
        case recordedAt   = "recorded_at"
        case appName      = "app_name"
        case windowTitle  = "window_title"
        case ideProject   = "ide_project"
        case gitRemote    = "git_remote"
        case gitBranch    = "git_branch"
        case browserUrl   = "browser_url"
        case isIdle       = "is_idle"
        case idleSeconds  = "idle_seconds"
    }
}
