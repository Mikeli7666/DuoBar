import AppKit
import SwiftUI

@MainActor
final class MenuBarController: NSObject {
    private static let hoverCloseDelay: TimeInterval = 0.25

    private let statusItem: NSStatusItem
    private var panel: PopoverPanel?
    private var hostingController: NSHostingController<StatusPopoverView>?
    private var isClosing = false
    private var closeWorkItem: DispatchWorkItem?
    private var isPanelVisible: Bool { panel?.isVisible == true && !isClosing }
    private let statusStore: SystemStatusStore
    private var hostingView: PassthroughHostingView<DuoStatusView>?
    private var popoverTrackingView: HoverTrackingContainerView?
    private var lengthAnimationTimer: Timer?
    private var pendingHoverClose: DispatchWorkItem?
    private var hoverCloseGeneration: UInt = 0
    private var defaultsObserver: NSObjectProtocol?
    private var applicationResignObserver: NSObjectProtocol?
    private var globalOutsideClickMonitor: Any?
    private var hoverInteraction = HoverPopoverInteraction(
        isEnabled: UserDefaults.standard.bool(forKey: PreferenceKeys.openOnHover)
    )
    private var isInvalidated = false

    init(statusStore: SystemStatusStore) {
        self.statusStore = statusStore
        statusItem = NSStatusBar.system.statusItem(
            withLength: MenuBarIconSize.statusItemWidth(for: MenuBarIconSize.storedScale())
        )
        super.init()
        configureStatusItem()
        configurePopover()
        observeHoverPreference()
        observeApplicationActivity()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }

        statusItem.isVisible = true
        button.target = self
        button.action = #selector(togglePopover)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.image = nil
        button.title = ""
        button.toolTip = localized("DuoBar system status")

        let rootView = DuoStatusView(statusStore: statusStore) { [weak self] width in
            self?.setStatusItemLength(width)
        }
        let hostingView = PassthroughHostingView(rootView: rootView)
        hostingView.onHoverChanged = { [weak self] isInside in
            guard let self else { return }
            let commands = isInside
                ? self.hoverInteraction.statusItemEntered()
                : self.hoverInteraction.statusItemExited()
            self.perform(commands)
        }
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
        let hostingController = NSHostingController(
            rootView: StatusPopoverView(statusStore: statusStore) { [weak self] in
                self?.closePopoverFromContent()
            }
        )
        let trackingView = HoverTrackingContainerView()
        trackingView.onHoverChanged = { [weak self] isInside in
            guard let self else { return }
            let commands = isInside
                ? self.hoverInteraction.popoverEntered()
                : self.hoverInteraction.popoverExited()
            self.perform(commands)
        }
        let contentViewController = NSViewController()
        contentViewController.view = trackingView
        contentViewController.addChild(hostingController)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        trackingView.addSubview(hostingController.view)
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: trackingView.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: trackingView.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: trackingView.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: trackingView.bottomAnchor)
        ])
        let panel = PopoverPanel(contentViewController: contentViewController)
        panel.onResignKey = { [weak self] in self?.panelDidResignKey() }
        panel.onCancel = { [weak self] in self?.handleOutsideClick() }
        self.panel = panel
        self.hostingController = hostingController
        popoverTrackingView = trackingView
    }

    @objc private func togglePopover() {
        // Never trust the state machine over what is actually on screen.
        if isPanelVisible {
            hoverInteraction.popoverShownExternally()
        }
        perform(hoverInteraction.statusItemClicked())
    }

    private func showPopover() {
        guard !isPanelVisible, let panel, let hostingController, let button = statusItem.button else { return }

        NSApp.activate(ignoringOtherApps: true)
        hostingController.view.layoutSubtreeIfNeeded()
        var size = hostingController.view.fittingSize
        if size.width < 1 || size.height < 1 { size = NSSize(width: 304, height: 352) }
        PopoverPresentationState.shared.prepareToShow()
        closeWorkItem?.cancel()
        closeWorkItem = nil
        isClosing = false
        panel.present(below: button, size: size)
        // Give SwiftUI one frame to draw the hidden state, then animate in.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
            PopoverPresentationState.shared.show()
        }
        installOutsideClickMonitors()
        statusStore.setPopoverActive(true)
        // Let the accessory app finish activating and the popover become key
        // before asking CoreLocation to present its native authorization UI.
        DispatchQueue.main.async { [weak self] in
            self?.statusStore.requestWiFiSSIDAccess(trigger: .popoverOpened)
        }
    }

    private func closePopover() {
        guard isPanelVisible else {
            removeOutsideClickMonitors()
            return
        }
        dismissPanel()
    }

    // MARK: - Outside-click dismissal

    private static let outsideClickMask: NSEvent.EventTypeMask = [
        .leftMouseDown, .rightMouseDown, .otherMouseDown
    ]

    /// Dismisses the popover when the user presses on another app or on another
    /// menu bar icon. Global monitors only observe events sent to other
    /// processes, so clicks inside DuoBar (the popover, its Wi-Fi password
    /// sheet, and the status item itself) never reach this handler. Mouse
    /// events need no Accessibility permission.
    private func installOutsideClickMonitors() {
        removeOutsideClickMonitors()

        globalOutsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: Self.outsideClickMask
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleOutsideClick()
            }
        }
    }

    private func removeOutsideClickMonitors() {
        if let globalOutsideClickMonitor {
            NSEvent.removeMonitor(globalOutsideClickMonitor)
            self.globalOutsideClickMonitor = nil
        }
    }

    private func handleOutsideClick() {
        guard !isInvalidated, isPanelVisible else { return }
        cancelHoverClose()
        _ = hoverInteraction.clickedOutside()
        // `close()` rather than `performClose(_:)`: an attached sheet or the
        // nested Nearby Networks popover can make `performClose` a no-op, which
        // would leave the popover on screen while the state says it is closed.
        dismissPanel()
    }

    /// True while a sheet (Wi-Fi password) or a nested popover (Nearby
    /// Networks) is attached to the popover window.
    private var popoverHasAttachedWindows: Bool {
        guard let window = panel else { return false }
        if window.attachedSheet != nil { return true }
        return window.childWindows?.contains(where: { $0.isVisible }) ?? false
    }

    private func closePopoverFromContent() {
        perform(hoverInteraction.popoverClosedExternally())
        closePopover()
    }

    private func perform(_ commands: [HoverPopoverCommand]) {
        guard !isInvalidated else { return }
        for command in commands {
            switch command {
            case .open:
                showPopover()
            case .close:
                closePopover()
            case .scheduleClose:
                scheduleHoverClose()
            case .cancelClose:
                cancelHoverClose()
            }
        }
    }

    private func scheduleHoverClose() {
        cancelHoverClose()
        let generation = hoverCloseGeneration
        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                guard let self, self.hoverCloseGeneration == generation else { return }
                self.pendingHoverClose = nil
                if self.popoverHasAttachedWindows {
                    self.perform(self.hoverInteraction.popoverEngaged())
                    return
                }
                self.perform(self.hoverInteraction.closeDelayElapsed())
            }
        }
        pendingHoverClose = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Self.hoverCloseDelay,
            execute: workItem
        )
    }

    private func cancelHoverClose() {
        hoverCloseGeneration &+= 1
        pendingHoverClose?.cancel()
        pendingHoverClose = nil
    }

    private func observeHoverPreference() {
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let enabled = UserDefaults.standard.bool(forKey: PreferenceKeys.openOnHover)
                let commands = self.hoverInteraction.setEnabled(enabled)
                self.perform(commands)
            }
        }
    }

    private func observeApplicationActivity() {
        applicationResignObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: NSApp,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.perform(self.hoverInteraction.applicationResignedActive())
            }
        }
    }

    #if DEBUG
    func setPopoverVisibleForMarketingCapture(_ visible: Bool) {
        guard isPanelVisible != visible else { return }
        if visible {
            showPopover()
        } else {
            closePopoverFromContent()
        }
    }
    #endif

    private func setStatusItemLength(_ requestedLength: CGFloat) {
        guard !isInvalidated else { return }
        // A zero, negative, or non-finite width would leave a running app with
        // no visible menu bar item, so fall back to the stored icon size.
        let targetLength = requestedLength.isFinite && requestedLength > 1
            ? requestedLength
            : MenuBarIconSize.statusItemWidth(for: MenuBarIconSize.storedScale())
        lengthAnimationTimer?.invalidate()

        guard UserDefaults.standard.bool(forKey: PreferenceKeys.animationsEnabled) else {
            statusItem.length = targetLength
            return
        }

        let startLength = statusItem.length
        guard abs(startLength - targetLength) > 0.5 else { return }
        let startDate = Date()
        let duration: TimeInterval = 0.34

        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self else {
                    timer.invalidate()
                    return
                }

                let elapsed = Date().timeIntervalSince(startDate)
                let progress = min(max(elapsed / duration, 0), 1)
                let eased = 1 - pow(1 - progress, 3)
                self.statusItem.length = startLength + (targetLength - startLength) * eased

                if progress >= 1 {
                    self.statusItem.length = targetLength
                    timer.invalidate()
                    self.lengthAnimationTimer = nil
                }
            }
        }
        lengthAnimationTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func invalidate() {
        guard !isInvalidated else { return }
        isInvalidated = true
        removeOutsideClickMonitors()
        cancelHoverClose()
        lengthAnimationTimer?.invalidate()
        lengthAnimationTimer = nil
        panel?.orderOut(nil)
        panel = nil
        hostingController = nil
        if let defaultsObserver {
            NotificationCenter.default.removeObserver(defaultsObserver)
            self.defaultsObserver = nil
        }
        if let applicationResignObserver {
            NotificationCenter.default.removeObserver(applicationResignObserver)
            self.applicationResignObserver = nil
        }
        popoverTrackingView?.removeFromSuperview()
        popoverTrackingView = nil
        hostingView?.removeFromSuperview()
        hostingView = nil
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    deinit {
        if let globalOutsideClickMonitor {
            NSEvent.removeMonitor(globalOutsideClickMonitor)
        }
        pendingHoverClose?.cancel()
        lengthAnimationTimer?.invalidate()
        if let defaultsObserver {
            NotificationCenter.default.removeObserver(defaultsObserver)
        }
        if let applicationResignObserver {
            NotificationCenter.default.removeObserver(applicationResignObserver)
        }
        if !isInvalidated {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
    }
}

extension MenuBarController {
    /// Hides the panel and runs the cleanup the popover delegate used to do.
    func dismissPanel() {
        guard isPanelVisible else { return }
        isClosing = true
        PopoverPresentationState.shared.hide()
        removeOutsideClickMonitors()
        statusStore.setPopoverActive(false)
        perform(hoverInteraction.popoverClosedExternally())
        // Keep the window up until the fade-out has finished.
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                guard let self, self.isClosing else { return }
                self.isClosing = false
                self.panel?.orderOut(nil)
            }
        }
        closeWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + PopoverMotion.closeDuration + 0.03, execute: work)
    }

    /// Stands in for `.transient`: closes when key moves to another window of
    /// this app (for example Settings). Clicks in other apps are handled by the
    /// global outside-click monitor.
    func panelDidResignKey() {
        #if DEBUG
        if MarketingCaptureMode.isEnabled { return }
        #endif
        guard !hoverInteraction.isEnabled else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.isPanelVisible, !self.isInvalidated else { return }
            // A click on the status item is handled by its own action.
            guard !self.hoverInteraction.isPointerOverStatusItem else { return }
            guard NSApp.isActive,
                  self.panel?.isKeyWindow != true,
                  !self.popoverHasAttachedWindows else { return }
            self.handleOutsideClick()
        }
    }
}

private final class PassthroughHostingView<Content: View>: NSHostingView<Content> {
    var onHoverChanged: ((Bool) -> Void)?
    private var hoverTrackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTrackingArea {
            removeTrackingArea(hoverTrackingArea)
        }
        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self
        )
        addTrackingArea(trackingArea)
        hoverTrackingArea = trackingArea
    }

    override func mouseEntered(with event: NSEvent) {
        onHoverChanged?(true)
    }

    override func mouseExited(with event: NSEvent) {
        onHoverChanged?(false)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}

final class HoverTrackingContainerView: NSView {
    var onHoverChanged: ((Bool) -> Void)?
    private var hoverTrackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTrackingArea {
            removeTrackingArea(hoverTrackingArea)
        }
        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self
        )
        addTrackingArea(trackingArea)
        hoverTrackingArea = trackingArea
    }

    override func mouseEntered(with event: NSEvent) {
        onHoverChanged?(true)
    }

    override func mouseExited(with event: NSEvent) {
        onHoverChanged?(false)
    }

}
