import SwiftUI

/// Drives the popover's open/close "blur + fade". StatusPopoverView observes
/// `isShown`; MenuBarController flips it around ordering the panel on/off
/// screen. FilmTimeline (promo tooling) uses the same three calls.
@MainActor
final class PopoverPresentationState: ObservableObject {
    static let shared = PopoverPresentationState()
    private init() {}

    @Published private(set) var isShown = false

    /// Blur radius (pt) of the hidden state: the content sharpens from this
    /// radius while it fades in, and softens back to it while it fades out.
    let hiddenBlur: CGFloat = PopoverMotion.hiddenBlur

    /// Puts the content in the hidden state instantly (no animation), so the
    /// panel can be ordered in without flashing the finished popover.
    func prepareToShow() {
        guard isShown else { return }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { isShown = false }
    }

    /// Animates to the shown state.
    func show() {
        guard !isShown else { return }
        isShown = true
    }

    /// Animates to the hidden state.
    func hide() {
        guard isShown else { return }
        isShown = false
    }
}

/// All timing in one place. Estimated from frame-by-frame analysis of the
/// native Control Center recording: open settles in about 0.2 s (blur and
/// alpha resolve together, no scale or movement), close takes about 0.25 s.
enum PopoverMotion {
    static let hiddenBlur: CGFloat = 12

    static let openOpacity: Animation = .easeOut(duration: 0.18)
    static let openBlur: Animation = .easeOut(duration: 0.22)
    static let close: Animation = .easeInOut(duration: 0.22)

    /// How long the panel stays on screen after `hide()` so the close
    /// animation can finish before the window is ordered out.
    static let closeDuration: TimeInterval = 0.24
}
