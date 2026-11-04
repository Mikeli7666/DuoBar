import AppKit

/// Borderless, fully transparent panel that replaces NSPopover so each
/// SwiftUI tile can float as its own glass shape.
@MainActor
final class PopoverPanel: NSPanel {
    var onResignKey: (@MainActor () -> Void)?
    var onCancel: (@MainActor () -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    init(contentViewController: NSViewController) {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: true
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        self.contentViewController = contentViewController
    }

    override func resignKey() {
        super.resignKey()
        onResignKey?()
    }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }

    /// Sizes the panel and places it centered under the status item,
    /// clamped to the visible area of the screen.
    func present(below button: NSStatusBarButton, size: NSSize) {
        guard let buttonWindow = button.window else { return }
        setContentSize(size)
        let buttonFrame = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let visible = (buttonWindow.screen ?? NSScreen.main)?.visibleFrame ?? .zero
        var x = buttonFrame.midX - size.width / 2
        x = min(max(x, visible.minX + 8), visible.maxX - size.width - 8)
        let y = buttonFrame.minY - size.height - 6
        setFrameOrigin(NSPoint(x: x, y: y))
        makeKeyAndOrderFront(nil)
    }
}
