import AppKit
import SwiftUI

/// Which Liquid Glass look the popover tiles use (macOS 26+).
///
/// The native Control Center always renders its glass in the dark appearance:
/// over a bright backdrop the tile settles on a mid grey so the white labels
/// stay readable, over a dark backdrop it lifts slightly. `.clear` glass does
/// not adapt, so it left white text on white tiles over bright content.
///
/// The default is `regularDark`. The other two exist so the look can be
/// compared on a real Mac without rebuilding:
///   defaults write com.mikeli.duobar duoBar.debug.popoverGlassVariant -string clear
///   defaults delete com.mikeli.duobar duoBar.debug.popoverGlassVariant
/// then close and reopen the popover.
enum PopoverGlassVariant: String {
    /// Adaptive regular glass, panel forced to the dark appearance (native look).
    case regularDark
    /// Adaptive regular glass in the system appearance.
    case regular
    /// The previous look: clear glass, no adaptation.
    case clear

    static let defaultsKey = "duoBar.debug.popoverGlassVariant"

    static var current: PopoverGlassVariant {
        PopoverGlassVariant(rawValue: UserDefaults.standard.string(forKey: defaultsKey) ?? "") ?? .regularDark
    }

    /// Appearance to force on the popover panel; nil follows the system.
    var forcedAppearance: NSAppearance? {
        self == .regularDark ? NSAppearance(named: .darkAqua) : nil
    }
}

/// Pill-shaped tile used by every popover row. Liquid Glass on macOS 26 and
/// later, a translucent material on older systems. The parameters of the
/// extension are kept so existing call sites compile; every tile is a capsule.
struct PopoverCardBackground: ViewModifier {
    @AppStorage(PopoverGlassVariant.defaultsKey)
    private var variantRaw = PopoverGlassVariant.regularDark.rawValue

    private var variant: PopoverGlassVariant {
        PopoverGlassVariant(rawValue: variantRaw) ?? .regularDark
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        let shape = Capsule(style: .continuous)
        if #available(macOS 26.0, *) {
            content
                .padding(.horizontal, 6)
                .glassEffect(variant == .clear ? Glass.clear : Glass.regular, in: shape)
                .overlay(
                    shape
                        .strokeBorder(Self.rim(strength: Self.rimStrength), lineWidth: 1.2)
                        .allowsHitTesting(false)
                )
        } else {
            content
                .padding(.horizontal, 6)
                .background(.regularMaterial, in: shape)
                .overlay(shape.strokeBorder(.primary.opacity(0.08), lineWidth: 0.5))
        }
    }

    /// Overall strength of the rim highlight; raise it for a brighter edge,
    /// lower it for a subtler one (1.0 is about twice the previous build).
    private static let rimStrength = 1.0

    /// Thin rim highlight: bright on the top-left, a faint line all the way
    /// round, a second lift on the bottom-right, like the native tiles.
    private static func rim(strength: Double) -> LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .white.opacity(0.70 * strength), location: 0.0),
                .init(color: .white.opacity(0.13 * strength), location: 0.42),
                .init(color: .white.opacity(0.13 * strength), location: 0.60),
                .init(color: .white.opacity(0.36 * strength), location: 1.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
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
