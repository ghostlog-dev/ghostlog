import CoreGraphics
import AppKit

struct WindowInfo {
    let appName: String
    let windowTitle: String
}

final class WindowTracker {
    func activeWindow() -> WindowInfo? {
        if !CGPreflightScreenCaptureAccess() {
            print("[WindowTracker] ❌ Screen Recording permission not granted — requesting...")
            CGRequestScreenCaptureAccess()
            return nil
        }

        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else { return nil }

        for window in windowList {
            guard
                let layer = window[kCGWindowLayer as String] as? Int,
                layer == 0,
                let pid = window[kCGWindowOwnerPID as String] as? pid_t,
                let app = NSRunningApplication(processIdentifier: pid),
                app.isActive
            else { continue }

            let appName = window[kCGWindowOwnerName as String] as? String ?? ""
            let title   = window[kCGWindowName as String] as? String ?? ""
            return WindowInfo(appName: appName, windowTitle: title)
        }
        return nil
    }
}
