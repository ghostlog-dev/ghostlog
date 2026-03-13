import AppKit
import SwiftUI

final class MainWindowState: ObservableObject {
    @Published var tab: MainTab = .today
}

final class WindowManager {
    static let shared = WindowManager()

    private var mainWindow: NSWindow?
    private let windowState = MainWindowState()

    func open(tab: MainTab = .today) {
        windowState.tab = tab

        if let existing = mainWindow {
            if !existing.isVisible { existing.center() }
            NSApp.activate(ignoringOtherApps: true)
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 740, height: 560),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        w.title = "Ghostlog"
        w.contentView = NSHostingView(
            rootView: MainView().environmentObject(windowState)
        )
        w.center()
        w.isReleasedWhenClosed = false
        w.collectionBehavior = [.managed, .moveToActiveSpace]
        mainWindow = w

        NSApp.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)
    }

    func openToday()    { open(tab: .today) }
    func openSettings() { open(tab: .settings) }
}
