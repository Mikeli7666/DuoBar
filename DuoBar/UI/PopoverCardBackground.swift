import SwiftUI

/// Pill-shaped tile used by every popover row. Liquid Glass on macOS 26 and
/// later, a translucent material on older systems. The parameters are kept so
/// existing call sites compile; every tile is a capsule now.
struct PopoverCardBackground: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        let shape = Capsule(style: .continuous)
        if #available(macOS 26.0, *) {
            content
                .padding(.horizontal, 6)
                .glassEffect(.regular.tint(.black.opacity(0.28)), in: shape)
        } else {
            content
                .padding(.horizontal, 6)
                .background(.regularMaterial, in: shape)
                .overlay(shape.strokeBorder(.primary.opacity(0.08), lineWidth: 0.5))
        }
    }
}

extension View {
    func popoverCardBackground(cornerRadius: CGFloat, fillOpacity: Double) -> some View {
        modifier(PopoverCardBackground())
    }
}

/// Groups the popover's glass tiles so they render and sample the backdrop
/// together on macOS 26; a plain pass-through on older systems.
struct PopoverGlassContainer<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: 2) { content }
        } else {
            content
        }
    }
}
