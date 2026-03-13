import ApplicationServices
import Foundation

final class BrowserURLTracker {

    // Chromium-based browsers that support AppleScript URL access
    private let chromiumApps: Set<String> = [
        "Google Chrome", "Microsoft Edge", "Brave Browser", "Arc",
        "Chromium", "Vivaldi", "Opera", "Sigmaos",
    ]

    // Firefox-based browsers (no AppleScript URL support — use Accessibility API)
    private let firefoxApps: Set<String> = [
        "Firefox", "Firefox Developer Edition", "Firefox Nightly",
        "Zen", "Zen Browser",
    ]

    func currentURL(appName: String, pid: pid_t) -> String? {
        if chromiumApps.contains(appName) {
            return chromiumURL(appName: appName)
        } else if appName == "Safari" || appName == "Safari Technology Preview" {
            return safariURL()
        } else if firefoxApps.contains(appName) {
            return accessibilityURL(pid: pid)
        } else {
            // Unknown browser — try accessibility as fallback
            return accessibilityURL(pid: pid)
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

    private func accessibilityURL(pid: pid_t) -> String? {
        let app = AXUIElementCreateApplication(pid)
        return findURLInApp(app)
    }

    private func findURLInApp(_ app: AXUIElement) -> String? {
        var ref: AnyObject?
        guard AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &ref) == .success,
              let window = ref as! AXUIElement? else { return nil }
        return findURLInElement(window, depth: 0)
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
