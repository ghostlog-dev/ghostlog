import Foundation

final class GitHookManager {
    private static let marker = "# ghostlog-hook"

    private let hookPath: URL
    private let hooksDir: URL

    init(hooksDirectory: URL? = nil) {
        let dir = hooksDirectory ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/git/hooks")
        hooksDir  = dir
        hookPath  = dir.appendingPathComponent("post-commit")
    }

    var isInstalled: Bool {
        guard let content = try? String(contentsOf: hookPath) else { return false }
        return content.contains(Self.marker)
    }

    func install() throws {
        try FileManager.default.createDirectory(at: hooksDir, withIntermediateDirectories: true)

        let script = """
        #!/bin/sh
        \(Self.marker)
        API_URL="https://api.ghostlog.nl"
        TOKEN=$(/usr/bin/security find-generic-password -s "com.ghostlog.app" -a "token" -w 2>/dev/null)
        if [ -z "$TOKEN" ]; then exit 0; fi
        GIT_REMOTE=$(git remote get-url origin 2>/dev/null || echo "")
        GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
        GIT_HASH=$(git rev-parse HEAD 2>/dev/null || echo "")
        GIT_SHORT=$(git rev-parse --short HEAD 2>/dev/null || echo "")
        GIT_MESSAGE=$(git log -1 --pretty=%s 2>/dev/null || echo "")
        NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        curl -sf -X POST "$API_URL/api/heartbeat" \\
          -H "Authorization: Bearer $TOKEN" \\
          -H "Content-Type: application/json" \\
          -d "{\\"recorded_at\\":\\"$NOW\\",\\"app_name\\":\\"git\\",\\"window_title\\":\\"git commit on $GIT_BRANCH\\",\\"ide_project\\":null,\\"git_remote\\":\\"$GIT_REMOTE\\",\\"git_branch\\":\\"$GIT_BRANCH\\",\\"browser_url\\":null,\\"is_idle\\":false,\\"idle_seconds\\":0}" \\
          >/dev/null 2>&1 &
        curl -sf -X POST "$API_URL/api/commits" \\
          -H "Authorization: Bearer $TOKEN" \\
          -H "Content-Type: application/json" \\
          -d "{\\"hash\\":\\"$GIT_HASH\\",\\"short_hash\\":\\"$GIT_SHORT\\",\\"message\\":$(echo "$GIT_MESSAGE" | /usr/bin/python3 -c "import json,sys; print(json.dumps(sys.stdin.read().strip()))"),\\"branch\\":\\"$GIT_BRANCH\\",\\"repo\\":\\"$GIT_REMOTE\\",\\"committed_at\\":\\"$NOW\\"}" \\
          >/dev/null 2>&1 &
        exit 0
        """

        try script.write(to: hookPath, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: hookPath.path)

        // Set global hooksPath (best-effort — may fail if git not installed)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["config", "--global", "core.hooksPath", hooksDir.path]
        try? process.run()
        process.waitUntilExit()
    }

    func uninstall() {
        guard isInstalled else { return }
        try? FileManager.default.removeItem(at: hookPath)
    }
}
