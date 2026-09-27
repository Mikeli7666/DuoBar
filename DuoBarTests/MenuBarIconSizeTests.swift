import XCTest
@testable import DuoBar

final class MenuBarIconSizeTests: XCTestCase {
    func testDefaultScaleIsOne() {
        XCTAssertEqual(MenuBarIconSize.defaultScale, 1)
        XCTAssertEqual(MenuBarIconSize.resolve(nil), 1)
    }

    func testMissingAndNonFinitePreferencesResolveToDefault() {
        XCTAssertEqual(MenuBarIconSize.resolve(nil), 1)
        XCTAssertEqual(MenuBarIconSize.resolve(.nan), 1)
        XCTAssertEqual(MenuBarIconSize.resolve(.infinity), 1)
        XCTAssertEqual(MenuBarIconSize.resolve(-.infinity), 1)
    }

    func testStoredPreferenceUsesTheSameSanitizationPolicy() {
        let suiteName = "MenuBarIconSizeTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        XCTAssertEqual(MenuBarIconSize.storedScale(in: defaults), 1, accuracy: 0.0001)
        defaults.set(0.874, forKey: MenuBarIconSize.preferenceKey)
        XCTAssertEqual(MenuBarIconSize.storedScale(in: defaults), 0.85, accuracy: 0.0001)
    }

    func testScaleClampsAndQuantizesToFiveHundredths() {
        XCTAssertEqual(MenuBarIconSize.resolve(0.2), 0.8, accuracy: 0.0001)
        XCTAssertEqual(MenuBarIconSize.resolve(1.8), 1.05, accuracy: 0.0001)
        XCTAssertEqual(MenuBarIconSize.resolve(0.826), 0.85, accuracy: 0.0001)
        XCTAssertEqual(MenuBarIconSize.resolve(0.924), 0.90, accuracy: 0.0001)
        XCTAssertEqual(MenuBarIconSize.resolve(1.0), 1.0, accuracy: 0.0001)
    }

    func testProductionPresetsMapToExistingScaleModel() {
        XCTAssertEqual(MenuBarIconSize.minimumScale, 0.80, accuracy: 0.0001)
        XCTAssertEqual(MenuBarIconSize.defaultScale, 1.00, accuracy: 0.0001)
        XCTAssertEqual(MenuBarIconSize.maximumScale, 1.05, accuracy: 0.0001)
        XCTAssertEqual(MenuBarIconSize.resolve(MenuBarIconSize.minimumScale), 0.80, accuracy: 0.0001)
        XCTAssertEqual(MenuBarIconSize.resolve(MenuBarIconSize.defaultScale), 1.00, accuracy: 0.0001)
        XCTAssertEqual(MenuBarIconSize.resolve(MenuBarIconSize.maximumScale), 1.05, accuracy: 0.0001)
    }

    func testDefaultScaledMetricsExactlyPreserveStandardGeometry() {
        XCTAssertEqual(DuoGlyphMetrics.standard.scaled(by: 1), DuoGlyphMetrics.standard)
        XCTAssertEqual(DuoGlyphMetrics.standard.scaled(by: 1).statusItemWidth, 27, accuracy: 0.0001)
    }

    func testProductionWholeGlyphVerticalOffsetIsOnePoint() {
        XCTAssertEqual(DuoGlyphMetrics.menuBarVerticalOffset, 1, accuracy: 0.0001)
    }

    func testWholeGlyphVerticalOffsetIsIndependentOfIconScale() {
        for scale in [0.80, 0.85, 0.90, 0.95, 1.00, 1.05] {
            _ = DuoGlyphMetrics.standard.scaled(by: scale)
            XCTAssertEqual(DuoGlyphMetrics.menuBarVerticalOffset, 1, accuracy: 0.0001)
        }
    }

    func testMinimumScaledMetrics() {
        let metrics = DuoGlyphMetrics.standard.scaled(by: 0.8)
        XCTAssertEqual(metrics.overallSize, 19.2, accuracy: 0.0001)
        XCTAssertEqual(metrics.ringDiameter, 21.2, accuracy: 0.0001)
        XCTAssertEqual(metrics.ringLineWidth, 2.24, accuracy: 0.0001)
        XCTAssertEqual(metrics.arcLineWidth, 1.659130434, accuracy: 0.0001)
        XCTAssertEqual(metrics.ringPathDiameter, 19.540869566, accuracy: 0.0001)
        XCTAssertEqual(metrics.wifiSymbolSize, 9.92, accuracy: 0.0001)
        XCTAssertEqual(metrics.wifiYOffset, -1, accuracy: 0.0001)
        XCTAssertEqual(metrics.dotDiameter, 1.981739130, accuracy: 0.0001)
        XCTAssertEqual(metrics.dotSpacing, 1.413333334, accuracy: 0.0001)
        XCTAssertEqual(metrics.dotYOffset, 5.996521739, accuracy: 0.0001)
        XCTAssertEqual(metrics.ringYOffset, -0.64, accuracy: 0.0001)
        XCTAssertEqual(metrics.statusItemHorizontalPadding, 2.4, accuracy: 0.0001)
        XCTAssertEqual(metrics.statusItemWidth, 22, accuracy: 0.0001)
    }

    func testMaximumScaledMetrics() {
        let metrics = DuoGlyphMetrics.standard.scaled(by: 1.05)
        XCTAssertEqual(metrics.overallSize, 25.2, accuracy: 0.0001)
        XCTAssertEqual(metrics.ringDiameter, 27.825, accuracy: 0.0001)
        XCTAssertEqual(metrics.ringLineWidth, 2.94, accuracy: 0.0001)
        XCTAssertEqual(metrics.arcLineWidth, 2.177608695, accuracy: 0.0001)
        XCTAssertEqual(metrics.ringPathDiameter, 25.647391305, accuracy: 0.0001)
        XCTAssertEqual(metrics.wifiSymbolSize, 13.02, accuracy: 0.0001)
        XCTAssertEqual(metrics.wifiYOffset, -1.3125, accuracy: 0.0001)
        XCTAssertEqual(metrics.dotDiameter, 2.601032609, accuracy: 0.0001)
        XCTAssertEqual(metrics.dotSpacing, 1.855000000, accuracy: 0.0001)
        XCTAssertEqual(metrics.dotYOffset, 7.870434783, accuracy: 0.0001)
        XCTAssertEqual(metrics.ringYOffset, -0.84, accuracy: 0.0001)
        XCTAssertEqual(metrics.statusItemHorizontalPadding, 3.15, accuracy: 0.0001)
        XCTAssertEqual(metrics.statusItemWidth, 28.35, accuracy: 0.0001)
    }

    func testStatusItemWidthUsesMinimumAndSharedScalePolicy() {
        XCTAssertEqual(MenuBarIconSize.statusItemWidth(for: 0.80), 22, accuracy: 0.0001)
        XCTAssertEqual(MenuBarIconSize.statusItemWidth(for: 1.00), 27, accuracy: 0.0001)
        XCTAssertEqual(MenuBarIconSize.statusItemWidth(for: 1.05), 28.35, accuracy: 0.0001)
    }

    func testScalingGeometryDoesNotAlterAdaptiveDecisionData() {
        let candidate = PerformanceCandidate(
            metric: .cpu,
            severity: .serious,
            normalizedValue: 0.72,
            reason: .cpuSustained
        )
        let decision = PerformanceDecision(
            activeMetric: .cpu,
            severity: .serious,
            normalizedRingValue: 0.72,
            reason: .cpuSustained,
            candidate: candidate
        )
        let state = AdaptiveRingState.performance(metric: .cpu, value: 0.72)

        _ = DuoGlyphMetrics.standard.scaled(by: 0.8)
        _ = DuoGlyphMetrics.standard.scaled(by: 1.05)

        XCTAssertEqual(decision.activeMetric, .cpu)
        XCTAssertEqual(decision.normalizedRingValue, 0.72)
        XCTAssertEqual(state, .performance(metric: .cpu, value: 0.72))
        XCTAssertEqual(DuoGlyphMetrics.menuBarVerticalOffset, 1, accuracy: 0.0001)
    }
}
