import ApplicationServices
import Foundation
import OSLog

private let logger = Logger(subsystem: "com.ghostlog.app", category: "BrowserURL")

final class BrowserURLTracker {

    // Lowercase for case-insensitive matching (macOS app names vary: "zen", "Google Chrome", etc.)
    private let chromiumApps: Set<String> = [
        "google chrome", "microsoft edge", "brave browser", "arc",
        "chromium", "vivaldi", "opera", "sigmaos",
    ]

    private let safariApps: Set<String> = [
        "safari", "safari technology preview",
    ]

    // Firefox-based browsers (no AppleScript URL support — use Accessibility API)
    private let firefoxApps: Set<String> = [
        "firefox", "firefox developer edition", "firefox nightly",
        "zen", "zen browser",
    ]

    func currentURL(appName: String, pid: pid_t) -> String? {
        let lower = appName.lowercased()
        if chromiumApps.contains(lower) {
            let url = chromiumURL(appName: appName)
            logger.debug("[\(appName)] AppleScript → \(url ?? "nil")")
            return url
        } else if safariApps.contains(lower) {
            let url = safariURL()
            logger.debug("[\(appName)] AppleScript → \(url ?? "nil")")
            return url
        } else if firefoxApps.contains(lower) {
            return accessibilityURL(appName: appName, pid: pid)
        } else {
            return accessibilityURL(appName: appName, pid: pid)
        }
    }

    // MARK: - AppleScript (Chromium)

    private func chromiumURL(appName: String) -> String? {
        let script = """
        tell application "\(appName)"
            if (count of windows) > 0 then
                get URL of active tab of front window
            end if
        end tell
        """
        return runScript(script)
    }

    // MARK: - AppleScript (Safari)

    private func safariURL() -> String? {
        let script = """
        tell application "Safari"
            if (count of windows) > 0 then
                get URL of current tab of front window
            end if
        end tell
        """
        return runScript(script)
    }

    // MARK: - Accessibility API (Firefox / Zen)

    private func accessibilityURL(appName: String, pid: pid_t) -> String? {
        guard AXIsProcessTrusted() else {
            logger.warning("[\(appName)] AX permission not granted — requesting prompt")
            // Prompt the user via System Settings (same pattern as screen recording)
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
            Task { @MainActor in
                DebugLog.shared.append("⚠️ browser_url: Toegankelijkheid-toestemming niet verleend\n   Systeeminstellingen → Privacy → Toegankelijkheid → zet Ghostlog aan, herstart daarna de app")
            }
            return nil
        }

        let app = AXUIElementCreateApplication(pid)
        var windowRef: AnyObject?
        let windowResult = AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &windowRef)

        guard windowResult == .success, let window = windowRef as! AXUIElement? else {
            logger.debug("[\(appName)] AX: could not get focused window (error \(windowResult.rawValue))")
            return nil
        }

        if let url = findURLInElement(window, depth: 0) {
            logger.debug("[\(appName)] AX → \(url)")
            return url
        }

        logger.debug("[\(appName)] AX: no URL field found in accessibility tree")
        return nil
    }

    private func findURLInElement(_ element: AXUIElement, depth: Int) -> String? {
        guard depth < 8 else { return nil }

        var roleRef: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef)
        let role = roleRef as? String

        if role == kAXTextFieldRole || role == kAXComboBoxRole {
            var valueRef: AnyObject?
            AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueRef)
            if let value = valueRef as? String,
               value.hasPrefix("http://") || value.hasPrefix("https://") || value.hasPrefix("about:") {
                return value
            }
        }

        var childrenRef: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
              let children = childrenRef as? [AXUIElement] else { return nil }

        for child in children {
            if let url = findURLInElement(child, depth: depth + 1) {
                return url
            }
        }
        return nil
    }

    // MARK: - Helpers

    private func runScript(_ source: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", source]

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = stdout.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return output?.isEmpty == false ? output : nil
        } catch {
            return nil
        }
    }
}
