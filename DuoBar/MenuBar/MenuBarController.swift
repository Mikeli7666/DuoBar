import AppKit
import SwiftUI

@MainActor
final class MenuBarController: NSObject {
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private let statusStore: SystemStatusStore
    private var hostingView: PassthroughHostingView<DuoStatusView>?
    private var isInvalidated = false

    init(statusStore: SystemStatusStore) {
        self.statusStore = statusStore
        statusItem = NSStatusBar.system.statusItem(withLength: DuoGlyphMetrics.standard.statusItemWidth)
        super.init()
        configureStatusItem()
        configurePopover()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }

        button.target = self
        button.action = #selector(togglePopover)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.image = nil
        button.title = ""
        button.toolTip = "DuoBar system status"

        let rootView = DuoStatusView(statusStore: statusStore) { [weak self] width in
            self?.setStatusItemLength(width)
        }
        let hostingView = PassthroughHostingView(rootView: rootView)
        // The status item owns the width; intrinsic hosting constraints would
        // compete with the button while the percentage is inserted or removed.
        hostingView.sizingOptions = []
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: button.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: button.bottomAnchor)
        ])
        self.hostingView = hostingView
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.animates = true
        let controller = NSHostingController(
            rootView: StatusPopoverView(statusStore: statusStore) { [weak self] in
                self?.popover.performClose(nil)
            }
        )
        controller.sizingOptions = [.preferredContentSize]
        popover.contentViewController = controller
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: .zero, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func setStatusItemLength(_ targetLength: CGFloat) {
        guard !isInvalidated else { return }
        // Resize once, in step with SwiftUI, instead of animating the native
        // button separately from its content and the attached popover.
        let wasAnimating = popover.animates
        popover.animates = false
        defer { popover.animates = wasAnimating }
        statusItem.length = targetLength
        statusItem.button?.window?.contentView?.layoutSubtreeIfNeeded()
        if popover.isShown {
            // An empty rect tracks the whole button, including its new width.
            popover.positioningRect = .zero
        }
    }

    func invalidate() {
        guard !isInvalidated else { return }
        isInvalidated = true
        popover.performClose(nil)
        hostingView?.removeFromSuperview()
        hostingView = nil
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    deinit {
        if !isInvalidated {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
    }
}

private final class PassthroughHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}
