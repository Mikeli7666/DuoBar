import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    private(set) var window: NSWindow?

    func show(statusStore: SystemStatusStore) {
        if window == nil {
            let host = NSHostingController(rootView: SettingsView(statusStore: statusStore))
            let window = NSWindow(contentViewController: host)
            window.title = "DuoBar Settings"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        guard let window else { return }
        // Recover a minimized or off-screen window as well as a closed one.
        if window.isMiniaturized { window.deminiaturize(nil) }
        if !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(window.frame) }) {
            window.center()
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func close() {
        window?.close()
    }
}
