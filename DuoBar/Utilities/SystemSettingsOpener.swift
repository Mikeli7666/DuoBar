import AppKit
import Foundation

enum SystemSettingsOpener {
    enum Pane: Equatable, Sendable {
        case wifi
        case network
        case battery
        case sound
    }

    static func pane(for network: NetworkStatus) -> Pane {
        switch network.transport {
        case .ethernet, .other:
            return .network
        case .wifi, .none:
            return .wifi
        }
    }

    static func urlStrings(for pane: Pane) -> [String] {
        switch pane {
        case .wifi:
            [
                "x-apple.systempreferences:com.apple.wifi-settings-extension",
                "x-apple.systempreferences:com.apple.Network-Settings.extension",
            ]
        case .network:
            [
                "x-apple.systempreferences:com.apple.Network-Settings.extension",
                "x-apple.systempreferences:com.apple.wifi-settings-extension",
            ]
        case .battery:
            [
                "x-apple.systempreferences:com.apple.Battery-Settings.extension",
            ]
        case .sound:
            [
                "x-apple.systempreferences:com.apple.Sound-Settings.extension",
            ]
        }
    }

    @discardableResult
    static func open(_ pane: Pane) -> Bool {
        let workspace = NSWorkspace.shared
        for string in urlStrings(for: pane) {
            if let url = URL(string: string), workspace.open(url) {
                return true
            }
        }

        return workspace.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
    }
}
