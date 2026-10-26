import Foundation

enum HoverPopoverPresentationState: Equatable {
    case closed
    case hoverOpen
    case pinned
}

enum HoverPopoverCommand: Equatable {
    case open
    case close
    case scheduleClose
    case cancelClose
}

struct HoverPopoverInteraction {
    private(set) var state: HoverPopoverPresentationState = .closed
    private(set) var isEnabled: Bool
    private(set) var isPointerOverStatusItem = false
    private(set) var isPointerOverPopover = false
    private(set) var suppressHoverUntilStatusItemExit = false

    init(isEnabled: Bool = false) {
        self.isEnabled = isEnabled
    }

    mutating func setEnabled(_ enabled: Bool) -> [HoverPopoverCommand] {
        guard enabled != isEnabled else { return [] }
        isEnabled = enabled

        guard !enabled else { return [] }
        suppressHoverUntilStatusItemExit = false
        guard state == .hoverOpen else { return [.cancelClose] }
        state = .closed
        return [.cancelClose, .close]
    }

    mutating func statusItemEntered() -> [HoverPopoverCommand] {
        isPointerOverStatusItem = true
        guard isEnabled else { return [] }
        guard !suppressHoverUntilStatusItemExit else { return [.cancelClose] }

        if state == .closed {
            state = .hoverOpen
            return [.cancelClose, .open]
        }
        return [.cancelClose]
    }

    mutating func statusItemExited() -> [HoverPopoverCommand] {
        isPointerOverStatusItem = false
        if suppressHoverUntilStatusItemExit {
            suppressHoverUntilStatusItemExit = false
        }
        return closeCommandsIfPointerIsOutside()
    }

    mutating func popoverEntered() -> [HoverPopoverCommand] {
        isPointerOverPopover = true
        guard state == .hoverOpen else { return [] }
        return [.cancelClose]
    }

    mutating func popoverExited() -> [HoverPopoverCommand] {
        isPointerOverPopover = false
        return closeCommandsIfPointerIsOutside()
    }

    mutating func statusItemClicked() -> [HoverPopoverCommand] {
        switch state {
        case .closed:
            state = .pinned
            return [.cancelClose, .open]
        case .hoverOpen:
            state = .pinned
            return [.cancelClose]
        case .pinned:
            state = .closed
            suppressHoverUntilStatusItemExit = isEnabled && isPointerOverStatusItem
            return [.cancelClose, .close]
        }
    }

    mutating func closeDelayElapsed() -> [HoverPopoverCommand] {
        guard state == .hoverOpen,
              !isPointerOverStatusItem,
              !isPointerOverPopover else {
            return []
        }
        state = .closed
        return [.close]
    }

    /// A mouse press landed outside the popover and DuoBar's status item, for
    /// example on another menu bar icon. System menu extras live in other
    /// processes, so AppKit's `.transient` behavior never sees those clicks.
    mutating func clickedOutside() -> [HoverPopoverCommand] {
        guard state != .closed else { return [] }
        state = .closed
        suppressHoverUntilStatusItemExit = false
        isPointerOverPopover = false
        return [.cancelClose, .close]
    }

    /// The popover is still on screen although the interaction believes it is
    /// closed (for example a close was blocked by a sheet). Treat it as pinned
    /// so the next click on the status item or outside the popover closes it.
    mutating func popoverShownExternally() {
        guard state == .closed else { return }
        state = .pinned
    }

    /// The user is working inside the popover (a sheet or a nested popover is
    /// open), so moving the pointer away must not dismiss it.
    mutating func popoverEngaged() -> [HoverPopoverCommand] {
        guard state == .hoverOpen else { return [] }
        state = .pinned
        return [.cancelClose]
    }

    mutating func applicationResignedActive() -> [HoverPopoverCommand] {
        closeCommandsIfPointerIsOutside()
    }

    mutating func popoverClosedExternally() -> [HoverPopoverCommand] {
        state = .closed
        suppressHoverUntilStatusItemExit = isEnabled && isPointerOverStatusItem
        isPointerOverPopover = false
        return [.cancelClose]
    }

    private func closeCommandsIfPointerIsOutside() -> [HoverPopoverCommand] {
        guard isEnabled,
              state == .hoverOpen,
              !isPointerOverStatusItem,
              !isPointerOverPopover else {
            return []
        }
        return [.scheduleClose]
    }
}
