import XCTest
@testable import DuoBar

final class DuoGlyphGeometryTests: XCTestCase {
    private let tolerance: CGFloat = 0.0005

    func testVolumeDotsSitOnTheRingCentreLine() {
        for index in 0..<4 {
            let x = DuoVolumeIndicatorGeometry.centerXOffsets[index]
            let y = DuoVolumeIndicatorGeometry.centerYOffsets[index]
            XCTAssertEqual(hypot(x, y), DuoVolumeIndicatorGeometry.centerRadiusRatio, accuracy: tolerance)
        }
    }

    func testVolumeDotsAreSymmetricAndTheOuterDotsSitHigher() {
        let xs = DuoVolumeIndicatorGeometry.centerXOffsets
        let ys = DuoVolumeIndicatorGeometry.centerYOffsets
        XCTAssertEqual(xs[0], -xs[3], accuracy: tolerance)
        XCTAssertEqual(xs[1], -xs[2], accuracy: tolerance)
        XCTAssertEqual(ys[0], ys[3], accuracy: tolerance)
        XCTAssertEqual(ys[1], ys[2], accuracy: tolerance)
        XCTAssertLessThan(ys[0], ys[1])
        XCTAssertLessThan(xs[0], xs[1])
        XCTAssertLessThan(xs[1], 0)
    }

    func testVolumeDotsSitBelowTheOpenEndsOfTheArc() {
        let metrics = DuoGlyphMetrics.standard
        let arcEndY = (metrics.ringPathDiameter / 2) * CGFloat(sin(metrics.arcStartDegrees * .pi / 180))
        let arcEndBottom = arcEndY + metrics.arcLineWidth / 2
        for y in DuoVolumeIndicatorGeometry.centerYOffsets {
            let dotTop = y * metrics.ringDiameter - metrics.dotDiameter / 2
            XCTAssertGreaterThan(dotTop, arcEndBottom)
        }
    }

    func testDotDiameterMatchesTheMeasuredRatio() {
        let metrics = DuoGlyphMetrics.standard
        XCTAssertEqual(
            metrics.dotDiameter / metrics.ringDiameter,
            DuoVolumeIndicatorGeometry.indicatorDiameterRatio,
            accuracy: tolerance
        )
    }

    func testRingStrokeAndGapMatchTheMeasuredValues() {
        let metrics = DuoGlyphMetrics.standard
        XCTAssertEqual(metrics.arcLineWidth / metrics.ringDiameter, 0.076378, accuracy: tolerance)
        XCTAssertEqual(metrics.arcGap, 120.22, accuracy: 0.01)
        XCTAssertEqual(metrics.arcStartDegrees, 150.11, accuracy: 0.01)
        XCTAssertEqual(metrics.arcEndDegrees, 389.89, accuracy: 0.01)
    }

    func testWiFiMarkIsOrderedAndFitsInsideTheRing() {
        typealias Geometry = DuoWiFiReferenceGeometry
        XCTAssertGreaterThan(Geometry.outerArcRadiusRatio, Geometry.middleArcRadiusRatio)
        XCTAssertGreaterThan(Geometry.middleArcRadiusRatio - Geometry.strokeWidthRatio / 2, Geometry.coreRadiusRatio)

        let outerTop = Geometry.apexYRatio - Geometry.outerArcRadiusRatio - Geometry.strokeWidthRatio / 2
        let ringInnerTop = -(0.5 - DuoGlyphMetrics.referenceArcStrokeRatio)
        XCTAssertGreaterThan(outerTop, ringInnerTop)
        XCTAssertGreaterThan(Geometry.apexYRatio, 0)
    }

    func testWiFiVerticalAdjustmentOnlyBridgesTheRingAndLayoutCentres() {
        let adjustment = DuoWiFiReferenceGeometry.verticalAdjustment(
            ringDiameter: 26.5,
            ringYOffset: -0.8,
            centerYOffset: -1.25
        )
        XCTAssertEqual(adjustment, 0.45, accuracy: 0.000_001)
    }
}
