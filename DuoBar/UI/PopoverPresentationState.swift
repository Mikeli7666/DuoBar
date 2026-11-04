import SwiftUI

/// Timings measured frame by frame from the native Control Center recording.
enum PopoverMotion {
    static let closeDuration: Double = 0.17
    static let openOpacity = Animation.easeOut(duration: 0.26)
    static let openBlur = Animation.easeOut(duration: 0.30).delay(0.02)
    static let close = Animation.linear(duration: closeDuration)
}

/// Drives the blur + fade used when the popover panel opens and closes.
@MainActor
final class PopoverPresentationState: ObservableObject {
    static let shared = PopoverPresentationState()

    @Published private(set) var isShown = false
    @Published private(set) var hiddenBlur: CGFloat = 10

    /// Call while the panel is still hidden, before it is ordered front.
    func prepareToShow() { hiddenBlur = 10 }

    func show() { isShown = true }

    func hide() {
        hiddenBlur = 4
        isShown = false
    }
}
