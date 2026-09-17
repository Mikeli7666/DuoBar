import SwiftUI

@main
struct DuoBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            if let statusStore = appDelegate.statusStore {
                SettingsView(statusStore: statusStore)
            }
        }
    }
}
