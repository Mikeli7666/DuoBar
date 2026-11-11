import AppKit
import SwiftUI

/// Owns the desktop widget: a borderless, non-activating panel at
/// desktop level — above the wallpaper, below the desktop icons — so
/// ordinary windows cover it exactly like a real desktop widget. It is
/// deliberately NOT a WidgetKit widget: system widgets cannot be dragged
/// freely or cycle modes on click, and this one must do both. Living in
/// the app process, it also reads the live status store directly (no
/// snapshot pipeline, no refresh budget).
@MainActor
final class DesktopWidgetController {
    private let statusStore: SystemStatusStore
    private var panel: NSPanel?
    private var defaultsObserver: NSObjectProtocol?

    init(statusStore: SystemStatusStore) {
        self.statusStore = statusStore
        // The size picker (and any future geometry preference) writes
        // through UserDefaults; watch for the panel's size inputs
        // changing under it. The notification also fires for unrelated
        // writes — applyCurrentSize() compares and no-ops.
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.applyCurrentSize() }
        }
    }

    deinit {
        if let defaultsObserver {
            NotificationCenter.default.removeObserver(defaultsObserver)
        }
    }

    /// Panel size for a size-picker scale: the medium card is 136×158.
    private static func panelSize(scale: CGFloat) -> NSSize {
        NSSize(width: (136 * scale).rounded(), height: (158 * scale).rounded())
    }

    private var currentScale: CGFloat {
        let raw = UserDefaults.standard.integer(forKey: PreferenceKeys.desktopWidgetSize)
        return (DesktopWidgetSize(rawValue: raw) ?? .medium).scale
    }

    /// Resizes the visible panel after the size preference changes,
    /// keeping its resting place and clamping it back on screen.
    private func applyCurrentSize() {
        guard let panel, panel.isVisible else { return }
        let target = Self.panelSize(scale: currentScale)
        guard target != panel.frame.size else { return }
        var frame = panel.frame
        frame.size = target
        if let screen = panel.screen ?? NSScreen.main {
            let visible = screen.visibleFrame
            frame.origin.x = min(max(frame.origin.x, visible.minX), max(visible.minX, visible.maxX - frame.width))
            frame.origin.y = min(max(frame.origin.y, visible.minY), max(visible.minY, visible.maxY - frame.height))
        }
        panel.setFrame(frame, display: true)
        UserDefaults.standard.set(frame.origin.x, forKey: PreferenceKeys.desktopWidgetFrameX)
        UserDefaults.standard.set(frame.origin.y, forKey: PreferenceKeys.desktopWidgetFrameY)
    }

    func setVisible(_ visible: Bool) {
        if visible {
            show()
        } else {
            panel?.orderOut(nil)
        }
    }

    private func show() {
        let panel = panel ?? makePanel()
        self.panel = panel
        if !restorePosition(panel) {
            positionDefault(panel)
        }
        panel.orderFrontRegardless()
        applyCurrentSize()
    }

    private func makePanel() -> NSPanel {
        let size = Self.panelSize(scale: currentScale)
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        // Above the desktop icon window itself: desktop files/folders must
        // not cover the widget. Still far below the normal window level,
        // so ordinary windows cover it as intended.
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isMovable = false // dragging is manual, in the surface view

        let surface = DesktopWidgetSurfaceView(frame: NSRect(origin: .zero, size: size))
        surface.onClick = { [weak self] in self?.cycleMode() }
        surface.onDragEnded = { origin in
            UserDefaults.standard.set(origin.x, forKey: PreferenceKeys.desktopWidgetFrameX)
            UserDefaults.standard.set(origin.y, forKey: PreferenceKeys.desktopWidgetFrameY)
        }

        let hosting = PassiveHostingView(rootView: DesktopWidgetView(statusStore: statusStore))
        hosting.frame = surface.bounds
        hosting.autoresizingMask = [.width, .height]
        surface.addSubview(hosting)

        panel.contentView = surface
        return panel
    }

    private func cycleMode() {
        let defaults = UserDefaults.standard
        let released = DesktopWidgetMode.releasedModes
        let current = DesktopWidgetMode(rawValue: defaults.integer(forKey: PreferenceKeys.desktopWidgetMode)) ?? .standard
        let index = released.firstIndex(of: current) ?? 0
        defaults.set(released[(index + 1) % released.count].rawValue,
                     forKey: PreferenceKeys.desktopWidgetMode)
    }

    private func restorePosition(_ panel: NSPanel) -> Bool {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: PreferenceKeys.desktopWidgetFrameX) != nil else { return false }
        var frame = panel.frame
        frame.origin = NSPoint(
            x: defaults.double(forKey: PreferenceKeys.desktopWidgetFrameX),
            y: defaults.double(forKey: PreferenceKeys.desktopWidgetFrameY)
        )
        guard NSScreen.screens.contains(where: { $0.visibleFrame.intersects(frame) }) else { return false }
        panel.setFrameOrigin(frame.origin)
        return true
    }

    private func positionDefault(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        panel.setFrameOrigin(NSPoint(
            x: visible.maxX - panel.frame.width - 18,
            y: visible.maxY - panel.frame.height - 18
        ))
    }
}

/// Hosting view that lets every mouse event fall through to the surface
/// beneath it: the widget's face has no interactive elements, so the
/// whole surface is a single click/drag target.
private final class PassiveHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

/// Manual click-vs-drag tracking for the widget surface. Window dragging
/// (isMovableByWindowBackground / performDrag) cannot be told apart from
/// a click, so the surface tracks the press itself: under 4 pt of travel
/// is a click (cycle mode); beyond it the window follows the pointer and
/// the resting place is reported on release.
private final class DesktopWidgetSurfaceView: NSView {
    var onClick: (() -> Void)?
    var onDragEnded: ((NSPoint) -> Void)?

    /// DuoBar is effectively never the active app when the widget is
    /// used, and the panel never activates — without this, AppKit treats
    /// every press as a window-activation click and swallows it before
    /// mouseDown, so neither clicking nor dragging ever fires.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        let startPointer = NSEvent.mouseLocation
        let startOrigin = window.frame.origin
        var dragged = false

        while let next = window.nextEvent(
            matching: [.leftMouseDragged, .leftMouseUp],
            until: .distantFuture,
            inMode: .eventTracking,
            dequeue: true
        ) {
            let pointer = NSEvent.mouseLocation
            let dx = pointer.x - startPointer.x
            let dy = pointer.y - startPointer.y

            switch next.type {
            case .leftMouseDragged:
                if !dragged && hypot(dx, dy) > 4 { dragged = true }
                if dragged {
                    window.setFrameOrigin(NSPoint(x: startOrigin.x + dx, y: startOrigin.y + dy))
                }
            case .leftMouseUp:
                if dragged {
                    onDragEnded?(window.frame.origin)
                } else {
                    onClick?()
                }
                return
            default:
                break
            }
        }
    }
}
