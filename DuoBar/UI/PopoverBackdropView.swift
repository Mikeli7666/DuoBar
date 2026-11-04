import AppKit

/// Light Gaussian blur of whatever is behind the popover panel, with no tint,
/// like the native Control Center. Uses the same backdrop layer the system
/// uses; if it is unavailable the view simply does nothing.
final class PopoverBackdropView: NSView {
    /// Blur radius in points. Measured from the native Control Center
    /// recording at roughly 2-6 pt; raise or lower to taste.
    static let blurRadius: CGFloat = 4

    init(cornerRadius: CGFloat = 30) {
        super.init(frame: .zero)
        if let backdrop = Self.makeBackdropLayer() {
            backdrop.cornerRadius = cornerRadius
            backdrop.cornerCurve = .continuous
            backdrop.masksToBounds = true
            layer = backdrop
            wantsLayer = true
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private static func makeBackdropLayer() -> CALayer? {
        guard let layerClass = NSClassFromString("CABackdropLayer") as? CALayer.Type,
              let filterClass = NSClassFromString("CAFilter") as? NSObject.Type,
              let filterObject = filterClass.perform(
                  NSSelectorFromString("filterWithType:"),
                  with: "gaussianBlur"
              )?.takeUnretainedValue() as? NSObject
        else { return nil }

        filterObject.setValue(blurRadius, forKey: "inputRadius")

        let layer = layerClass.init()
        layer.setValue(true, forKey: "windowServerAware")
        layer.setValue(UUID().uuidString, forKey: "groupName")
        layer.setValue(1.0, forKey: "scale")
        layer.filters = [filterObject]
        return layer
    }
}
