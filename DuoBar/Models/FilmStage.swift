#if DEBUG
import AppKit
import SwiftUI

/// A stage window that hosts the app's real menu-bar glyph (scaled up) and
/// the real popover over a wallpaper backdrop, all driven by the same
/// SystemStatusStore the film timeline scripts. The 24 pt menu-bar item can
/// never provide hero-size footage; this window renders the identical views
/// at capture size instead. Opened by FilmTimelinePlayer when the timeline
/// config sets `"stage": true`.
@MainActor
final class FilmStageController {
    static let shared = FilmStageController()

    private var window: NSWindow?

    func open(store: SystemStatusStore) {
        if let window {
            window.makeKeyAndOrderFront(nil)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1240, height: 780),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "DuoBar Film Stage"
        window.contentView = NSHostingView(rootView: FilmStageView(store: store))
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        self.window = window
        // The stage popover's visibility is driven by the timeline's popover
        // steps (see FilmTimelinePlayer); it starts hidden.
    }
}

private struct FilmStageView: View {
    @ObservedObject var store: SystemStatusStore

    var body: some View {
        ZStack {
            backdrop
            HStack(alignment: .center, spacing: 56) {
                ZStack {
                    Color.clear
                    DuoStatusView(statusStore: store, filmScale: 13)
                }
                .frame(width: 470, height: 470)

                StatusPopoverView(statusStore: store) {}
                    .frame(width: 304)
            }
            .padding(56)
        }
    }

    private var backdrop: some View {
        Group {
            if let image = Self.wallpaper {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(
                    colors: [
                        Color(red: 0.13, green: 0.10, blue: 0.35),
                        Color(red: 0.05, green: 0.06, blue: 0.20),
                        Color(red: 0.02, green: 0.02, blue: 0.08),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .ignoresSafeArea()
    }

    private static let wallpaper: NSImage? = {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("duobar-film/wallpaper.jpg")
        return NSImage(contentsOf: url)
    }()
}
#endif
