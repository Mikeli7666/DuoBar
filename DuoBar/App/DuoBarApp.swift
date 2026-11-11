import SwiftUI

@main
struct DuoBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
        }
        // Without this the Settings scene pins its window to the content
        // size and re-asserts that after the first manual resize; the
        // content size should be the window's minimum, not its fixed size.
        .windowResizability(.contentMinSize)
    }
}
