import XCTest
@testable import DuoBar

@MainActor
final class LaptopAdaptiveRingIntegrationTests: XCTestCase {
    func testLaptopUsesBatteryBeforeTargetThenAdaptiveAndReturnsToBatteryOnUnplug() {
        let (store, _) = makeLaptopStore()
        store.applyDebugBatteryStatus(battery(20, charging: true, plugged: true))
        XCTAssertFalse(store.usesAdaptiveRing)

        store.applyDebugBatteryStatus(battery(69, charging: true, plugged: true))
        XCTAssertEqual(store.laptopRingModeState.mode, .battery)
        store.applyDebugBatteryStatus(battery(70, charging: true, plugged: true))
        XCTAssertEqual(store.laptopRingModeState.mode, .adaptive)
        XCTAssertTrue(store.usesAdaptiveRing)

        store.applyDebugBatteryStatus(battery(43))
        XCTAssertEqual(store.laptopRingModeState, .battery)
        XCTAssertFalse(store.usesAdaptiveRing)
        XCTAssertEqual(DuoGlyphState(status: store.status).batteryProgress, 0.43, accuracy: 0.0001)
    }

    func testDebugSimulationSequenceResetsFullTargetSessionBeforeEnteringAdaptive() {
        let (store, _) = makeLaptopStore()

        store.applyDebugBatteryStatus(battery(100))
        store.applyDebugAdaptiveBatteryBaseline()
        XCTAssertEqual(store.status.battery, battery(100))
        XCTAssertEqual(store.laptopRingModeState, .battery)
        XCTAssertFalse(store.usesReleasedAdaptiveRing)

        // The DEBUG helpers drive the hidden 50% unplug -> charging controller
        // setup without replacing the 100% value visible in the glyph.
        store.applyDebugAdaptiveChargingBaseline()
        XCTAssertEqual(store.status.battery, battery(100, charging: true, plugged: true))
        XCTAssertEqual(store.laptopRingModeState.mode, .battery)
        XCTAssertEqual(store.laptopRingModeState.sessionStartPercentage, 50)
        XCTAssertEqual(store.laptopRingModeState.targetPercentage, 80)
        store.reachDebugAdaptiveTarget()

        XCTAssertEqual(store.laptopRingModeState.mode, .adaptive)
        XCTAssertEqual(store.laptopRingModeState.sessionStartPercentage, 50)
        XCTAssertEqual(store.laptopRingModeState.targetPercentage, 80)
        XCTAssertTrue(store.usesReleasedAdaptiveRing)
        XCTAssertEqual(store.status.battery, battery(100, charging: true, plugged: true))

        let presentation = DuoPersistentRingPresentationResolver.resolve(
            mode: .adaptive,
            battery: store.status.battery,
            adaptiveProgress: AdaptiveRingVisualTarget.neutralBaseline,
            batteryColorCodingEnabled: true
        )
        XCTAssertEqual(presentation.mode, .adaptive)
        XCTAssertEqual(presentation.batteryPresentation.boltPlacement, .none)
        XCTAssertEqual(presentation.batteryPresentation.colorRole, .monochrome)

        store.applyDebugBatteryStatus(battery(80))
        XCTAssertEqual(store.laptopRingModeState, .battery)
        XCTAssertFalse(store.usesReleasedAdaptiveRing)
    }

    func testPluggedChargingPauseWaitsForActualChargingBaselineAndPreservesItAfterward() {
        let (store, _) = makeLaptopStore()
        store.applyDebugBatteryStatus(battery(55, plugged: true))
        XCTAssertNil(store.laptopRingModeState.sessionStartPercentage)
        XCTAssertFalse(store.usesAdaptiveRing)

        store.applyDebugBatteryStatus(battery(60, charging: true, plugged: true))
        XCTAssertEqual(store.laptopRingModeState.sessionStartPercentage, 60)
        XCTAssertEqual(store.laptopRingModeState.targetPercentage, 90)
        store.applyDebugBatteryStatus(battery(75, plugged: true))
        XCTAssertEqual(store.laptopRingModeState.sessionStartPercentage, 60)
        XCTAssertFalse(store.usesAdaptiveRing)
    }

    func testFullDelayIntegratesThroughStoreAndUnplugCancelsIt() {
        let scheduler = IntegrationManualScheduler()
        let (store, _) = makeLaptopStore(delay: .fiveMinutes, scheduler: scheduler)
        store.applyDebugBatteryStatus(battery(80, charging: true, plugged: true))
        store.applyDebugBatteryStatus(battery(100, plugged: true, full: true))
        XCTAssertEqual(store.laptopRingModeState.mode, .battery)
        XCTAssertTrue(store.laptopRingModeState.isWaitingForFullChargeDelay)

        scheduler.advance(by: 5 * 60)
        XCTAssertEqual(store.laptopRingModeState.mode, .adaptive)

        store.applyDebugBatteryStatus(battery(100, full: true))
        XCTAssertEqual(store.laptopRingModeState, .battery)
        scheduler.fireAllIncludingCancelled()
        XCTAssertEqual(store.laptopRingModeState, .battery)
    }

    func testAdaptiveGlyphSuppressesBatteryBoltAndBatteryColorWhilePreservingNetworkAndVolume() {
        let status = SystemStatus(
            battery: battery(70, charging: true, plugged: true),
            network: DebugNetworkState.strong.status,
            audio: DebugAudioDeviceState.builtIn.status,
            bluetooth: .unavailable
        )
        let adaptive = DuoGlyphState(
            status: status,
            ringPresentation: .adaptive(progress: 0.62),
            batteryColorCodingEnabled: true
        )

        XCTAssertEqual(adaptive.batteryPresentation.boltPlacement, .none)
        XCTAssertEqual(adaptive.batteryPresentation.colorRole, .monochrome)
        XCTAssertEqual(adaptive.centerState, .wifi(.strong))
        XCTAssertEqual(adaptive.volumeActiveDotCount, 3)
    }

    func testDesktopAndMacBookAdaptiveResolveTheSamePersistentRingPresentation() {
        let battery = battery(70, charging: true, plugged: true)
        let desktop = DuoPersistentRingPresentationResolver.resolve(
            mode: .adaptive,
            battery: battery,
            adaptiveProgress: 0.62,
            batteryColorCodingEnabled: true
        )
        let macBook = DuoPersistentRingPresentationResolver.resolve(
            mode: .adaptive,
            battery: battery,
            adaptiveProgress: 0.62,
            batteryColorCodingEnabled: true
        )

        XCTAssertEqual(desktop, macBook)
        XCTAssertEqual(macBook.mode, .adaptive)
        XCTAssertEqual(macBook.progress, 0.62, accuracy: 0.0001)
        XCTAssertEqual(macBook.batteryPresentation.boltPlacement, .none)
        XCTAssertEqual(macBook.batteryPresentation.colorRole, .monochrome)
    }

    func testResolvedRingPresentationKeepsBatteryAndAdaptiveSemanticsIsolated() {
        let chargingBattery = battery(70, charging: true, plugged: true)
        let batteryRing = DuoPersistentRingPresentationResolver.resolve(
            mode: .battery,
            battery: chargingBattery,
            adaptiveProgress: 0.25,
            batteryColorCodingEnabled: true
        )
        let adaptiveRing = DuoPersistentRingPresentationResolver.resolve(
            mode: .adaptive,
            battery: chargingBattery,
            adaptiveProgress: AdaptiveRingVisualTarget.neutralBaseline,
            batteryColorCodingEnabled: true
        )

        XCTAssertEqual(batteryRing.mode, .battery)
        XCTAssertNotEqual(batteryRing.batteryPresentation.boltPlacement, .none)
        XCTAssertEqual(adaptiveRing.mode, .adaptive)
        XCTAssertEqual(adaptiveRing.progress, 0.25, accuracy: 0.0001)
        XCTAssertEqual(adaptiveRing.batteryPresentation.boltPlacement, .none)
        XCTAssertEqual(adaptiveRing.batteryPresentation.colorRole, .monochrome)
    }

    func testAdaptiveColorCodingUsesExistingResolverWithoutBatteryColorLeakage() {
        let cpu = decision(metric: .cpu, severity: .serious, value: 0.86)
        let presentation = AdaptiveRingColorResolver.resolve(
            state: .performance(metric: .cpu, value: 0.86),
            decision: cpu,
            colorCodingEnabled: true
        )
        XCTAssertEqual(presentation.role, .cpu)
        XCTAssertEqual(presentation.intensity, 0.82)
        XCTAssertEqual(
            AdaptiveRingColorResolver.resolve(
                state: .brightness(0.7),
                decision: .idle,
                colorCodingEnabled: true
            ).role,
            .monochrome
        )
    }

    func testAdaptivePipelineUsesExistingBrightnessCPUAndReleaseBehavior() {
        let brightness = DisplayBrightnessSnapshot(mainDisplay: integrationDisplay, availability: .available(0.64), sampledAt: 10)
        let coordinator = AdaptiveRingCoordinator()
        XCTAssertEqual(coordinator.resolve(brightness: brightness, performance: .idle, at: 10), .brightness(0.64))

        var engine = PerformanceDecisionEngine()
        _ = engine.update(with: snapshot(at: 0, cpu: 0.86))
        let cpu = engine.update(with: snapshot(at: 4, cpu: 0.86))
        XCTAssertEqual(coordinator.resolve(brightness: brightness, performance: cpu, at: 10), .performance(metric: .cpu, value: 0.86))

        _ = engine.update(with: snapshot(at: 12, cpu: 0.1))
        let released = engine.update(with: snapshot(at: 18, cpu: 0.1))
        let refreshedBrightness = DisplayBrightnessSnapshot(
            mainDisplay: integrationDisplay,
            availability: .available(0.64),
            sampledAt: 18
        )
        XCTAssertEqual(coordinator.resolve(brightness: refreshedBrightness, performance: released, at: 18), .brightness(0.64))
    }

    func testExistingMemoryThermalAndNeutralAdaptiveStatesRemainAvailable() {
        var memoryEngine = PerformanceDecisionEngine()
        _ = memoryEngine.update(with: snapshot(at: 0, memory: .serious))
        XCTAssertEqual(memoryEngine.update(with: snapshot(at: 4, memory: .serious)).activeMetric, .memory)

        var thermalEngine = PerformanceDecisionEngine()
        XCTAssertEqual(thermalEngine.update(with: snapshot(at: 0, thermal: .serious)).activeMetric, .thermal)

        let unavailable = DisplayBrightnessSnapshot(mainDisplay: integrationDisplay, availability: .unavailable, sampledAt: 1)
        XCTAssertEqual(AdaptiveRingCoordinator().resolve(brightness: unavailable, performance: .idle, at: 1), .neutral)
    }

    func testAirPodsEventRetainsPriorityOverPerformanceCenterOverride() {
        let device = DebugAudioDeviceState.airPods.status.defaultOutput!
        let event = StatusEvent(kind: .audioDeviceConnected(device), priority: .informational)
        let state = DuoGlyphState(
            status: SystemStatus(
                battery: battery(70, charging: true, plugged: true),
                network: DebugNetworkState.strong.status,
                audio: DebugAudioDeviceState.airPods.status,
                bluetooth: .unavailable
            ),
            presentation: .event(event),
            ringPresentation: .adaptive(progress: 0.8),
            centerStateOverride: .performanceCPU
        )
        XCTAssertEqual(state.centerState, .airPodsPro)
        XCTAssertEqual(state.volumeActiveDotCount, 3)
    }

    func testDesktopIsAdaptiveFromLaunchAndDoesNotUseLaptopChargingState() {
        let controller = LaptopRingModeController(hasInternalBattery: false, fullChargeDelay: .immediately)
        let store = SystemStatusStore(
            startServices: false,
            deviceContext: DeviceContext(hasInternalBattery: false),
            laptopRingModeController: controller
        )
        store.applyDebugBatteryStatus(battery(40))

        XCTAssertTrue(store.usesAdaptiveRing)
        XCTAssertFalse(store.usesLaptopAdaptiveRing)
        XCTAssertEqual(store.laptopRingModeState, .battery)
    }

    func testReleasePresentationUsesLaptopAdaptiveModeWhenControllerIsAdaptive() {
        let controller = LaptopRingModeController(hasInternalBattery: true, fullChargeDelay: .immediately)
        let store = SystemStatusStore(
            startServices: false,
            deviceContext: DeviceContext(hasInternalBattery: true),
            laptopRingModeController: controller
        )
        store.applyDebugBatteryStatus(battery(80, charging: true, plugged: true))
        store.applyDebugBatteryStatus(battery(100, charging: true, plugged: true, full: true))
        XCTAssertEqual(store.laptopRingModeState.mode, .adaptive)
        XCTAssertTrue(store.usesReleasedAdaptiveRing)
    }

    func testChargingToAdaptiveKeepsPriorityControllerIndependentAndRestoresLiveNetwork() {
        let controller = LaptopRingModeController(hasInternalBattery: true)
        let store = SystemStatusStore(
            startServices: false,
            deviceContext: DeviceContext(hasInternalBattery: true),
            laptopRingModeController: controller
        )
        store.applyDebugNetworkState(.strong)
        store.applyDebugBatteryStatus(battery(50))
        store.applyDebugBatteryStatus(battery(50, charging: true, plugged: true))
        XCTAssertEqual(store.priorityController.presentation.event?.kind, .charging)

        store.applyDebugBatteryStatus(battery(80, charging: true, plugged: true))
        XCTAssertEqual(store.laptopRingModeState.mode, .adaptive)
        XCTAssertEqual(store.priorityController.presentation.event?.kind, .charging)

        let entry = DuoGlyphState(
            status: store.status,
            presentation: store.priorityController.presentation,
            ringPresentation: .adaptive(progress: AdaptiveRingVisualTarget.neutralBaseline),
            centerStateOverride: .adaptiveEntry
        )
        XCTAssertEqual(entry.centerState, .adaptiveEntry)
        XCTAssertEqual(entry.batteryProgress, 0.25)
        XCTAssertEqual(entry.batteryPresentation.boltPlacement, .none)
        XCTAssertEqual(entry.batteryPresentation.colorRole, .monochrome)

        store.applyDebugNetworkState(.weak)
        let restored = DuoGlyphState(
            status: store.status,
            presentation: store.priorityController.presentation,
            ringPresentation: .adaptive(progress: AdaptiveRingVisualTarget.neutralBaseline)
        )
        XCTAssertEqual(restored.centerState, .wifi(.weak))
    }

    func testReleasePresentationStillUsesAdaptiveRingForDesktop() {
        let store = SystemStatusStore(
            startServices: false,
            deviceContext: DeviceContext(hasInternalBattery: false)
        )
        XCTAssertTrue(store.usesReleasedAdaptiveRing)
    }

    func testNewMonitoringSessionClearsPriorAdaptiveMetricBeforeReentry() {
        let monitor = AdaptiveRingMonitor(brightnessReader: IntegrationBrightnessReader())
        monitor.refresh(at: 0)
        XCTAssertNotNil(monitor.performanceSnapshot)
        monitor.resetForNewMonitoringSession()

        XCTAssertNil(monitor.performanceSnapshot)
        XCTAssertEqual(monitor.performanceDecision, .idle)
        XCTAssertEqual(monitor.state, .neutral)
        XCTAssertFalse(monitor.isMonitoring)
    }

    func testLaptopAdaptiveEntryUsesLiveBrightnessUpdatesAndUnplugReleasesTheLease() {
        let (store, _) = makeLaptopStore()
        let reader = MutableIntegrationBrightnessReader(value: 0.20)
        let monitor = AdaptiveRingMonitor(brightnessReader: reader)
        let owner = UUID()

        store.applyDebugBatteryStatus(battery(20, charging: true, plugged: true))
        XCTAssertFalse(store.usesAdaptiveRing)
        XCTAssertFalse(monitor.isMonitoring)
        #if DEBUG
        XCTAssertEqual(monitor.debugTestSource, .live)
        #endif

        store.applyDebugBatteryStatus(battery(70, charging: true, plugged: true))
        XCTAssertTrue(store.usesLaptopAdaptiveRing)
        monitor.resetForNewMonitoringSession()
        monitor.acquire(owner: owner)
        XCTAssertTrue(monitor.isMonitoring)
        XCTAssertEqual(monitor.state, .brightness(0.20))

        reader.value = 0.80
        monitor.refresh(at: 1)
        XCTAssertEqual(monitor.brightnessSnapshot?.availability, .available(0.80))
        XCTAssertEqual(monitor.state, .brightness(0.80))
        XCTAssertEqual(AdaptiveRingVisualTarget(state: monitor.state).progress, 0.80, accuracy: 0.0001)

        store.applyDebugBatteryStatus(battery(43))
        XCTAssertFalse(store.usesAdaptiveRing)
        monitor.release(owner: owner)
        XCTAssertFalse(monitor.isMonitoring)

        reader.value = 0.35
        store.applyDebugBatteryStatus(battery(20, charging: true, plugged: true))
        store.applyDebugBatteryStatus(battery(70, charging: true, plugged: true))
        monitor.resetForNewMonitoringSession()
        monitor.acquire(owner: owner)
        XCTAssertEqual(monitor.state, .brightness(0.35))
        monitor.release(owner: owner)
    }

    func testIconSizeEndpointsRemainSharedByBatteryAndAdaptiveGlyphs() {
        for scale in [0.80, 1.05] {
            let metrics = DuoGlyphMetrics.standard.scaled(by: scale)
            XCTAssertEqual(metrics.statusItemWidth, max(22, 27 * CGFloat(scale)), accuracy: 0.0001)
            XCTAssertEqual(
                DuoGlyphState(status: SystemStatus.unavailable, ringPresentation: .adaptive(progress: 0.25)).batteryProgress,
                0.25
            )
        }
    }

    private func makeLaptopStore(
        delay: LaptopAdaptiveFullChargeDelay = .immediately,
        scheduler: IntegrationManualScheduler? = nil
    ) -> (SystemStatusStore, LaptopRingModeController) {
        let controller = LaptopRingModeController(
            hasInternalBattery: true,
            fullChargeDelay: delay,
            scheduler: scheduler ?? IntegrationManualScheduler()
        )
        return (
            SystemStatusStore(
                startServices: false,
                deviceContext: DeviceContext(hasInternalBattery: true),
                laptopRingModeController: controller
            ),
            controller
        )
    }

    private func battery(
        _ percentage: Int?,
        charging: Bool = false,
        plugged: Bool = false,
        full: Bool = false
    ) -> BatteryStatus {
        BatteryStatus(
            percentage: percentage,
            isCharging: charging,
            isPluggedIn: plugged,
            isFullyCharged: full,
            isAvailable: true
        )
    }

    private func snapshot(
        at timestamp: TimeInterval,
        cpu: Double? = nil,
        memory: MemoryStressEstimate = .normal,
        thermal: PerformanceThermalState = .nominal
    ) -> PerformanceSnapshot {
        PerformanceSnapshot(
            timestamp: timestamp,
            cpuLoad: cpu,
            memory: MemorySnapshot(
                totalBytes: 100,
                availableBytes: memory == .normal ? 40 : 5,
                compressedBytes: 0,
                pageOutsPerSecond: 0,
                stress: memory
            ),
            thermalState: thermal
        )
    }

    private func decision(metric: PerformanceMetric, severity: PerformanceSeverity, value: Double) -> PerformanceDecision {
        PerformanceDecision(
            activeMetric: metric,
            severity: severity,
            normalizedRingValue: value,
            reason: .cpuSustained,
            candidate: PerformanceCandidate(metric: metric, severity: severity, normalizedValue: value, reason: .cpuSustained)
        )
    }
}

@MainActor
private final class IntegrationManualScheduler: LaptopRingModeScheduling {
    private final class ScheduledTask: LaptopRingModeScheduledTask {
        let deadline: TimeInterval
        let action: @MainActor () -> Void
        var cancelled = false

        init(deadline: TimeInterval, action: @escaping @MainActor () -> Void) {
            self.deadline = deadline
            self.action = action
        }

        func cancel() { cancelled = true }
    }

    private var now: TimeInterval = 0
    private var tasks: [ScheduledTask] = []

    func schedule(after interval: TimeInterval, action: @escaping @MainActor () -> Void) -> LaptopRingModeScheduledTask {
        let task = ScheduledTask(deadline: now + interval, action: action)
        tasks.append(task)
        return task
    }

    func advance(by interval: TimeInterval) {
        now += interval
        let due = tasks.filter { !$0.cancelled && $0.deadline <= now }
        tasks.removeAll { !$0.cancelled && $0.deadline <= now }
        due.forEach { $0.action() }
    }

    func fireAllIncludingCancelled() {
        let pending = tasks
        tasks.removeAll()
        pending.forEach { $0.action() }
    }
}

private struct IntegrationBrightnessReader: DisplayBrightnessReading {
    func readMainDisplay(at timestamp: TimeInterval) -> DisplayBrightnessSnapshot {
        DisplayBrightnessSnapshot(mainDisplay: integrationDisplay, availability: .available(0.5), sampledAt: timestamp)
    }
}

private final class MutableIntegrationBrightnessReader: DisplayBrightnessReading {
    var value: Double

    init(value: Double) {
        self.value = value
    }

    func readMainDisplay(at timestamp: TimeInterval) -> DisplayBrightnessSnapshot {
        DisplayBrightnessSnapshot(
            mainDisplay: integrationDisplay,
            availability: .available(value),
            sampledAt: timestamp
        )
    }
}

private let integrationDisplay = MainDisplayDescriptor(
    displayID: 1,
    vendorID: 1,
    productID: 1,
    serialNumber: 1
)
