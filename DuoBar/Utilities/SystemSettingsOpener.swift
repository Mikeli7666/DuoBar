import AppKit
import Foundation

enum SystemSettingsOpener {
    static let soundURLString = "x-apple.systempreferences:com.apple.Sound-Settings.extension"

    @discardableResult
    static func openSoundSettings() -> Bool {
        let workspace = NSWorkspace.shared
        if let url = URL(string: soundURLString), workspace.open(url) {
            return true
        }
        return workspace.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
    }
}
