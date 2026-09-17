import CoreGraphics

struct DuoGlyphMetrics: Equatable {
    static let standard = DuoGlyphMetrics(
        overallSize: 27,
        ringDiameter: 26.5,
        ringLineWidth: 2.7,
        arcGap: 110,
        wifiSymbolSize: 15,
        wifiYOffset: -1.1,
        dotDiameter: 2.55,
        dotSpacing: 1.9,
        dotYOffset: 11.4
    )

    static let canvasSize: CGFloat = 32

    var overallSize: CGFloat
    var ringDiameter: CGFloat
    var ringLineWidth: CGFloat
    var arcGap: Double
    var wifiSymbolSize: CGFloat
    var wifiYOffset: CGFloat
    var dotDiameter: CGFloat
    var dotSpacing: CGFloat
    var dotYOffset: CGFloat

    let ringYOffset: CGFloat = -0.8

    var arcStartDegrees: Double { 90 + arcGap / 2 }
    var arcEndDegrees: Double { 450 - arcGap / 2 }
    var statusItemWidth: CGFloat { overallSize + 3 }
    var chargingIndicatorWidth: CGFloat { overallSize * 0.30 + 2 }

    // Dot centers sit on the same circle as the battery ring. Keep the tuning
    // offset relative to that circle instead of flattening the bottom row.
    func dotPosition(at index: Int) -> CGPoint {
        let radius = ringDiameter / 2
        let x = (CGFloat(index) - 1.5) * (dotDiameter + dotSpacing)
        let y = ringYOffset + sqrt(max(0, radius * radius - x * x))
            + dotYOffset - Self.standard.dotYOffset
        return CGPoint(x: x, y: y)
    }

    // Reserve the complete silhouette even as the battery arc or label hides,
    // so a status update never moves the icon up or down.
    func verticalBounds(style: DuoGlyphStyle) -> ClosedRange<CGFloat> {
        let ringTop = ringYOffset - ringDiameter / 2 - ringLineWidth / 2
        let top = style == .splitRing ? min(ringTop, -16.5) : ringTop
        let bottom = dotPosition(at: 1).y + dotDiameter / 2
        return top...bottom
    }

    func verticalCenteringOffset(style: DuoGlyphStyle) -> CGFloat {
        let bounds = verticalBounds(style: style)
        return -(bounds.lowerBound + bounds.upperBound) / 2
    }

    func sized(_ size: CGFloat) -> DuoGlyphMetrics {
        var copy = self
        copy.overallSize = size
        return copy
    }
}

#if DEBUG
enum DuoGlyphTuningKeys {
    static let overallSize = "debug.duoGlyph.overallSize"
    static let ringDiameter = "debug.duoGlyph.ringDiameter"
    static let ringLineWidth = "debug.duoGlyph.ringLineWidth"
    static let arcGap = "debug.duoGlyph.arcGap"
    static let wifiSymbolSize = "debug.duoGlyph.wifiSymbolSize"
    static let wifiYOffset = "debug.duoGlyph.wifiYOffset"
    static let dotDiameter = "debug.duoGlyph.dotDiameter"
    static let dotSpacing = "debug.duoGlyph.dotSpacing"
    static let dotYOffset = "debug.duoGlyph.dotYOffset"
}
#endif
