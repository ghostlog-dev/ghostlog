import Foundation

/// Wraps macOS Keychain access via `/usr/bin/security`.
///
/// Using the system `security` CLI (instead of `SecItemAdd`/`SecItemCopyMatching`)
/// means Keychain items are owned by `/usr/bin/security` rather than this app's
/// binary. That removes the app-specific ACL restriction, so:
///   • No authorization prompt appears after every rebuild (ad-hoc signing changes
///     the binary hash, which would normally invalidate the ACL).
///   • The CLI (`@klader/timetracking`) can read the same item via its own
///     `execFileSync('/usr/bin/security', ...)` call — same binary, no prompt.
enum KeychainHelper {

    static func saveToken(_ token: String, service: String = "com.ghostlog.app") {
        guard !token.isEmpty else {
            deleteToken(service: service)
            return
        }
        // Remove any existing entry first (ignore failure — may not exist).
        run("/usr/bin/security", args: [
            "delete-generic-password", "-s", service, "-a", "token",
        ])
        run("/usr/bin/security", args: [
            "add-generic-password", "-s", service, "-a", "token", "-w", token,
        ])
    }

    static func loadToken(service: String = "com.ghostlog.app") -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", service, "-a", "token", "-w"]
        let outPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError  = Pipe() // suppress "could not find" stderr noise
        do { try process.run() } catch { return nil }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        let raw = outPipe.fileHandleForReading.readDataToEndOfFile()
        let value = String(data: raw, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value.flatMap { $0.isEmpty ? nil : $0 }
    }

    static func deleteToken(service: String = "com.ghostlog.app") {
        run("/usr/bin/security", args: [
            "delete-generic-password", "-s", service, "-a", "token",
        ])
    }

    // MARK: - Private

    @discardableResult
    private static func run(_ path: String, args: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments     = args
        process.standardOutput = Pipe()
        process.standardError  = Pipe()
        try? process.run()
        process.waitUntilExit()
        return process.terminationStatus
    }
}
