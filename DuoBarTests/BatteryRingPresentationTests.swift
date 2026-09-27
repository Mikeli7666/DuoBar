import XCTest
@testable import DuoBar

final class BatteryRingPresentationTests: XCTestCase {
    func testColorCodingDefaultsToMonochrome() {
        XCTAssertEqual(presentation(percentage: 10, colorCoding: false).colorRole, .monochrome)
        XCTAssertEqual(presentation(percentage: 10, charging: true, colorCoding: false).colorRole, .monochrome)
    }

    func testMissingOrCorruptedColorCodingPreferenceIsSafelyOff() {
        let suiteName = "BatteryRingPresentationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        XCTAssertFalse(defaults.bool(forKey: PreferenceKeys.batteryColorCoding))
        defaults.set("not-a-boolean", forKey: PreferenceKeys.batteryColorCoding)
        XCTAssertFalse(defaults.bool(forKey: PreferenceKeys.batteryColorCoding))
    }

    func testChargingTakesColorPriority() {
        XCTAssertEqual(presentation(percentage: 15, charging: true, lowPowerMode: true).colorRole, .charging)
    }

    func testAuthoritativeFullSuppressesChargingColor() {
        XCTAssertEqual(
            presentation(percentage: 100, charging: true, pluggedIn: true, fullyCharged: true).colorRole,
            .monochrome
        )
    }

    func testLowPowerModeIsYellowSemanticRoleAtAnyLevel() {
        XCTAssertEqual(presentation(percentage: 10, lowPowerMode: true).colorRole, .lowPowerMode)
        XCTAssertEqual(presentation(percentage: 50, lowPowerMode: true).colorRole, .lowPowerMode)
    }

    func testLowBatteryIsStrictlyBelowTwentyPercent() {
        XCTAssertEqual(presentation(percentage: 19).colorRole, .lowBattery)
        XCTAssertEqual(presentation(percentage: 20).colorRole, .monochrome)
    }

    func testNormalBatteryRemainsMonochromeWithColorCoding() {
        XCTAssertEqual(presentation(percentage: 50).colorRole, .monochrome)
    }

    func testFinalExternalPowerColorPriorityMatrix() {
        XCTAssertEqual(
            presentation(percentage: 50, pluggedIn: true, colorCoding: true),
            BatteryRingPresentation(boltPlacement: .topGap, colorRole: .charging)
        )
        XCTAssertEqual(
            presentation(percentage: 50, pluggedIn: true, colorCoding: false),
            BatteryRingPresentation(boltPlacement: .topGap, colorRole: .monochrome)
        )
        XCTAssertEqual(
            presentation(percentage: 15, pluggedIn: true, lowPowerMode: true, colorCoding: true),
            BatteryRingPresentation(boltPlacement: .topGap, colorRole: .charging)
        )
        XCTAssertEqual(
            presentation(percentage: 15, pluggedIn: true, lowPowerMode: true, colorCoding: false),
            BatteryRingPresentation(boltPlacement: .topGap, colorRole: .monochrome)
        )
        XCTAssertEqual(presentation(percentage: 15, lowPowerMode: true).colorRole, .lowPowerMode)
        XCTAssertEqual(presentation(percentage: 15).colorRole, .lowBattery)
        XCTAssertEqual(presentation(percentage: 100, pluggedIn: true).colorRole, .charging)
        XCTAssertEqual(
            presentation(percentage: 100, pluggedIn: true, colorCoding: false).colorRole,
            .monochrome
        )
        XCTAssertEqual(presentation(percentage: 100).boltPlacement, .none)
    }

    func testPluggedStateIsAuthoritativeEvenWhenChargingIsPaused() {
        let paused = presentation(
            percentage: 80,
            charging: false,
            pluggedIn: true,
            fullyCharged: false,
            colorCoding: true
        )
        XCTAssertEqual(paused.boltPlacement, .topGap)
        XCTAssertEqual(paused.colorRole, .charging)
    }

    func testChargingBelowFullUsesTopGapBolt() {
        XCTAssertEqual(presentation(percentage: 20, charging: true).boltPlacement, .topGap)
    }

    func testUnpluggedBatteryHasNoBolt() {
        XCTAssertEqual(presentation(percentage: 80).boltPlacement, .none)
    }

    func testPluggedChargingPauseStillUsesTopGapBolt() {
        XCTAssertEqual(presentation(percentage: 50, pluggedIn: true).boltPlacement, .topGap)
    }

    func testAuthoritativeFullConnectedBatterySuppressesBolt() {
        XCTAssertEqual(
            presentation(percentage: 100, pluggedIn: true, fullyCharged: true).boltPlacement,
            .none
        )
    }

    func testRingMidpointDerivesFromSharedRingGeometry() {
        let metrics = DuoGlyphMetrics.standard
        XCTAssertEqual(
            DuoRingGeometry.midpoint(metrics: metrics),
            DuoRingGeometry.endpoint(metrics: metrics, progress: 0.5)
        )
    }

    func testReferenceArcUsesVisualOuterDiameterAndMeasuredStrokeRatio() {
        let metrics = DuoGlyphMetrics.standard
        XCTAssertEqual(metrics.ringPathDiameter + metrics.arcLineWidth, metrics.ringDiameter, accuracy: 0.0001)
        XCTAssertEqual(metrics.arcLineWidth / metrics.ringDiameter, 18.0 / 230.0, accuracy: 0.0001)
        XCTAssertEqual(metrics.arcGap, 120.2, accuracy: 0.0001)
    }

    func testRingEndpointUsesTheSameAngleAsTheArc() {
        let metrics = DuoGlyphMetrics.standard
        for percentage in [20, 50, 80, 99] {
            let progress = Double(percentage) / 100
            let arc = DuoArcShape(
                startDegrees: metrics.arcStartDegrees,
                endDegrees: metrics.arcEndDegrees,
                progress: progress
            )
            let endpoint = DuoRingGeometry.endpoint(metrics: metrics, progress: progress)
            let endpointAngle = atan2(endpoint.y - metrics.ringYOffset, endpoint.x) * 180 / .pi
            XCTAssertEqual(normalizedDegrees(endpointAngle), normalizedDegrees(arc.visibleEndDegrees), accuracy: 0.0001)
        }
    }

    func testEndpointGeometryScalesWithGlyphMetrics() {
        for scale in [0.80, 1.00, 1.05] {
            let metrics = DuoGlyphMetrics.standard.scaled(by: scale)
            let endpoint = DuoRingGeometry.endpoint(metrics: metrics, progress: 0.5)
            let expectedRadius = metrics.ringPathDiameter / 2
            let actualRadius = hypot(endpoint.x, endpoint.y - metrics.ringYOffset)
            XCTAssertEqual(actualRadius, expectedRadius, accuracy: 0.0001)
            XCTAssertEqual(DuoGlyphMetrics.menuBarVerticalOffset, 1, accuracy: 0.0001)
        }
    }

    func testChargingBelowFullPreservesNetworkCenter() {
        let state = DuoGlyphState(status: status(percentage: 50, charging: true, pluggedIn: true))
        XCTAssertEqual(state.centerState, .wifi(.strong))
        XCTAssertEqual(state.batteryPresentation.boltPlacement, .topGap)
    }

    func testAuthoritativeFullSuppressesBoltWithoutReplacingNetwork() {
        let state = DuoGlyphState(status: status(percentage: 100, pluggedIn: true, fullyCharged: true))
        XCTAssertEqual(state.centerState, .wifi(.strong))
        XCTAssertEqual(state.batteryPresentation.boltPlacement, .none)
    }

    func testUnpluggingFullBatteryRestoresNormalNetworkCenter() {
        let state = DuoGlyphState(status: status(percentage: 100, fullyCharged: true))
        XCTAssertEqual(state.centerState, .wifi(.strong))
        XCTAssertEqual(state.batteryPresentation.boltPlacement, .none)
    }

    func testAudioEventRetainsPriorityOverAuthoritativeFullCharge() {
        let device = AudioDeviceStatus(
            uid: "airpods", name: "AirPods Pro", transport: .bluetooth, isAlive: true,
            modelUID: "2027 4c", manufacturer: "Apple Inc.", terminalType: .headphones
        )
        let event = StatusEvent(kind: .audioDeviceConnected(device), priority: .informational)
        let state = DuoGlyphState(
            status: status(percentage: 100, pluggedIn: true, fullyCharged: true),
            presentation: .event(event)
        )
        XCTAssertEqual(state.centerState, .airPodsPro)
        XCTAssertEqual(state.batteryPresentation.boltPlacement, .none)
    }

    func testAdaptiveRingOverrideCannotLeakBatteryBolt() {
        let state = DuoGlyphState(
            status: status(percentage: 50, charging: true, pluggedIn: true),
            ringPresentation: .adaptive(progress: 0.72)
        )
        XCTAssertEqual(state.batteryPresentation.boltPlacement, .none)
    }

    func testReferenceMeasuredChargingPresentationConstants() {
        XCTAssertEqual(BatteryBoltPresentationConstants.opacity, 1, accuracy: 0.0001)
        XCTAssertEqual(BatteryBoltPresentationConstants.hiddenScale, 0, accuracy: 0.0001)
        XCTAssertEqual(BatteryBoltPresentationConstants.entranceDuration, 26.0 / 60.0, accuracy: 0.0001)
        XCTAssertEqual(BatteryBoltPresentationConstants.exitDuration, 22.0 / 60.0, accuracy: 0.0001)
        XCTAssertEqual(BatteryChargingAnimationProfile.trackEntranceDuration, 18.0 / 60.0, accuracy: 0.0001)
        XCTAssertEqual(DuoNativeVisualConstants.chargingTrackOpacity, 0.24, accuracy: 0.0001)
        XCTAssertEqual(DuoNativeVisualConstants.chargingColorDelay, 42.0 / 60.0, accuracy: 0.0001)
        XCTAssertEqual(DuoNativeVisualConstants.chargingColorTransitionDuration, 19.0 / 60.0, accuracy: 0.0001)
    }

    func testChargingEntranceSnapshotMatchesMeasuredStages() {
        XCTAssertEqual(
            BatteryChargingAnimationProfile.entranceSnapshot(elapsed: 0),
            BatteryChargingAnimationSnapshot(boltProgress: 0, trackProgress: 0, colorMix: 0)
        )

        let boltSettled = BatteryChargingAnimationProfile.entranceSnapshot(
            elapsed: BatteryChargingAnimationProfile.boltEntranceDuration
        )
        XCTAssertEqual(boltSettled.boltProgress, 1, accuracy: 0.0001)
        XCTAssertEqual(boltSettled.trackProgress, 1, accuracy: 0.0001)
        XCTAssertEqual(boltSettled.colorMix, 0, accuracy: 0.0001)

        let colorMidpoint = BatteryChargingAnimationProfile.entranceSnapshot(
            elapsed: BatteryChargingAnimationProfile.colorDelay
                + BatteryChargingAnimationProfile.colorTransitionDuration / 2
        )
        XCTAssertEqual(colorMidpoint.boltProgress, 1, accuracy: 0.0001)
        XCTAssertEqual(colorMidpoint.colorMix, 0.875, accuracy: 0.0001)

        XCTAssertEqual(
            BatteryChargingAnimationProfile.entranceSnapshot(
                elapsed: BatteryChargingAnimationProfile.entranceDuration
            ),
            BatteryChargingAnimationSnapshot(boltProgress: 1, trackProgress: 1, colorMix: 1)
        )
    }

    func testChargingExitAndInterruptionResolveWithoutStalePresentation() {
        let halfway = BatteryChargingAnimationProfile.exitSnapshot(
            elapsed: BatteryChargingAnimationProfile.exitDuration / 2
        )
        XCTAssertEqual(halfway.boltProgress, 0.5, accuracy: 0.0001)
        XCTAssertEqual(halfway.trackProgress, 0.5, accuracy: 0.0001)
        XCTAssertEqual(halfway.colorMix, 0.5, accuracy: 0.0001)

        XCTAssertEqual(
            BatteryChargingAnimationProfile.exitSnapshot(
                elapsed: BatteryChargingAnimationProfile.exitDuration
            ),
            BatteryChargingAnimationSnapshot(boltProgress: 0, trackProgress: 0, colorMix: 0)
        )
        XCTAssertEqual(
            BatteryChargingAnimationProfile.entranceSnapshot(
                elapsed: BatteryChargingAnimationProfile.boltEntranceDuration / 2
            ).colorMix,
            0,
            accuracy: 0.0001
        )
    }

    func testReduceMotionResolvesDirectlyToSemanticFinalState() {
        XCTAssertEqual(
            BatteryChargingAnimationProfile.resolvedSnapshot(
                showsBolt: true,
                usesChargingColor: true,
                reduceMotion: true
            ),
            BatteryChargingAnimationSnapshot(boltProgress: 1, trackProgress: 1, colorMix: 1)
        )
        XCTAssertEqual(
            BatteryChargingAnimationProfile.resolvedSnapshot(
                showsBolt: false,
                usesChargingColor: false,
                reduceMotion: true
            ),
            BatteryChargingAnimationSnapshot(boltProgress: 0, trackProgress: 0, colorMix: 0)
        )
    }

    func testReferenceBoltGeometryScalesAtAllSupportedIconSizes() {
        for scale in [0.80, 1.00, 1.05] {
            let metrics = DuoGlyphMetrics.standard.scaled(by: scale)
            let point = DuoRingGeometry.chargingBoltPoint(metrics: metrics)
            let expectedRadius = metrics.ringPathDiameter / 2
                + metrics.ringDiameter * BatteryChargingAnimationProfile.boltRadialOffsetRatio
            XCTAssertEqual(
                point.x,
                metrics.ringDiameter * BatteryChargingAnimationProfile.boltHorizontalOffsetRatio,
                accuracy: 0.0001
            )
            XCTAssertEqual(point.y - metrics.ringYOffset, -expectedRadius, accuracy: 0.0001)
            XCTAssertEqual(
                metrics.ringDiameter * BatteryChargingAnimationProfile.boltFontSizeRatio,
                DuoGlyphMetrics.standard.ringDiameter
                    * BatteryChargingAnimationProfile.boltFontSizeRatio * scale,
                accuracy: 0.0001
            )
        }
    }

    private func presentation(
        percentage: Int,
        charging: Bool = false,
        pluggedIn: Bool = false,
        fullyCharged: Bool = false,
        lowPowerMode: Bool = false,
        colorCoding: Bool = true
    ) -> BatteryRingPresentation {
        BatteryRingPresentation.resolve(
            battery: BatteryStatus(
                percentage: percentage,
                isCharging: charging,
                isPluggedIn: pluggedIn || charging,
                isFullyCharged: fullyCharged,
                isAvailable: true,
                isLowPowerModeEnabled: lowPowerMode
            ),
            colorCodingEnabled: colorCoding
        )
    }

    private func status(
        percentage: Int,
        charging: Bool = false,
        pluggedIn: Bool = false,
        fullyCharged: Bool = false
    ) -> SystemStatus {
        SystemStatus(
            battery: BatteryStatus(
                percentage: percentage,
                isCharging: charging,
                isPluggedIn: pluggedIn || charging,
                isFullyCharged: fullyCharged,
                isAvailable: true
            ),
            network: NetworkStatus(
                isAvailable: true, isConnected: true, transport: .wifi,
                interfaceName: "en0", isWiFiPoweredOn: true, ssid: "Test", rssi: -42
            ),
            audio: .unavailable,
            bluetooth: .unavailable
        )
    }

    private func normalizedDegrees(_ degrees: Double) -> Double {
        let normalized = degrees.truncatingRemainder(dividingBy: 360)
        return normalized < 0 ? normalized + 360 : normalized
    }
}
