import XCTest
@testable import DuoBar

final class AdaptiveRingTests: XCTestCase {
    private let coordinator = AdaptiveRingCoordinator(brightnessMaximumAge: 4)

    func testAvailableBrightnessIsBaselineWhenPerformanceIsIdle() {
        XCTAssertEqual(resolve(.available(0.63)), .brightness(0.63))
    }

    func testUnavailableBrightnessUsesNeutralBaseline() {
        let state = resolve(.unavailable)
        XCTAssertEqual(state, .neutral)
        XCTAssertNil(state.normalizedRingValue)
    }

    func testCPUPerformanceOverridesBrightness() {
        XCTAssertEqual(
            resolve(.available(0.3), performance: decision(.cpu, value: 0.72)),
            .performance(metric: .cpu, value: 0.72)
        )
    }

    func testMemoryPerformanceOverridesBrightness() {
        XCTAssertEqual(
            resolve(.available(0.3), performance: decision(.memory, value: 0.8)),
            .performance(metric: .memory, value: 0.8)
        )
    }

    func testThermalPerformanceOverridesBrightness() {
        XCTAssertEqual(
            resolve(.available(0.3), performance: decision(.thermal, value: 1)),
            .performance(metric: .thermal, value: 1)
        )
    }

    func testPerformanceReleaseReturnsToBrightness() {
        let active = resolve(.available(0.44), performance: decision(.cpu, value: 0.8))
        let released = resolve(.available(0.44), performance: .idle)
        XCTAssertEqual(active, .performance(metric: .cpu, value: 0.8))
        XCTAssertEqual(released, .brightness(0.44))
    }

    func testPerformanceReleaseReturnsToNeutralWhenBrightnessIsUnavailable() {
        XCTAssertEqual(
            resolve(.unavailable, performance: decision(.thermal, value: 0.82)),
            .performance(metric: .thermal, value: 0.82)
        )
        XCTAssertEqual(resolve(.unavailable, performance: .idle), .neutral)
    }

    func testStaleBrightnessUsesNeutralInsteadOfFabricatingZero() {
        let snapshot = DisplayBrightnessSnapshot(
            mainDisplay: display,
            availability: .available(0.7),
            sampledAt: 10
        )
        let state = coordinator.resolve(brightness: snapshot, performance: .idle, at: 15)
        XCTAssertEqual(state, .neutral)
        XCTAssertNil(state.normalizedRingValue)
    }

    func testInvalidBrightnessValuesAreUnavailableRatherThanZero() {
        XCTAssertEqual(DisplayBrightnessService.validatedBrightness(-0.01), .unavailable)
        XCTAssertEqual(DisplayBrightnessService.validatedBrightness(1.01), .unavailable)
        XCTAssertEqual(DisplayBrightnessService.validatedBrightness(.nan), .unavailable)
        XCTAssertEqual(DisplayBrightnessService.validatedBrightness(.infinity), .unavailable)
        XCTAssertEqual(DisplayBrightnessService.validatedBrightness(0), .available(0))
    }

    func testLinearBrightnessFallbackIsUsedOnlyWhenStandardBrightnessIsUnavailable() {
        XCTAssertEqual(
            DisplayBrightnessService.resolvedBrightness(standard: 0.22, linearFallback: 0.81),
            .available(0.22)
        )
        XCTAssertEqual(
            DisplayBrightnessService.resolvedBrightness(standard: nil, linearFallback: 0.81),
            .available(0.81)
        )
        XCTAssertEqual(
            DisplayBrightnessService.resolvedBrightness(standard: .nan, linearFallback: 0.47),
            .available(0.47)
        )
        XCTAssertEqual(
            DisplayBrightnessService.resolvedBrightness(standard: nil, linearFallback: nil),
            .unavailable
        )
    }

    func testMainDisplayIdentityRequiresUniqueMatch() {
        let exact = DisplayHardwareIdentity(vendorID: 10, productID: 20, serialNumber: 30)
        let other = DisplayHardwareIdentity(vendorID: 11, productID: 21, serialNumber: 31)
        XCTAssertEqual(
            DisplayHardwareIdentity.uniqueMatchIndex(for: display, candidates: [other, exact]),
            1
        )
        XCTAssertNil(
            DisplayHardwareIdentity.uniqueMatchIndex(for: display, candidates: [exact, exact])
        )
        XCTAssertNil(
            DisplayHardwareIdentity.uniqueMatchIndex(for: display, candidates: [other])
        )
    }

    func testDebugDesktopSimulationSelectsAdaptiveRing() {
        #if DEBUG
        let context = DeviceContextService().current(simulateDesktop: true)
        XCTAssertFalse(context.hasInternalBattery)
        XCTAssertEqual(context.ringBehavior, .adaptiveRing)
        #endif
    }

    #if DEBUG
    func testSyntheticBrightnessScenariosFlowThroughCoordinator() {
        for (scenario, expected) in [
            (AdaptiveRingSyntheticScenario.brightness25, 0.25),
            (.brightness50, 0.50),
            (.brightness75, 0.75),
            (.brightness100, 1.00)
        ] {
            let input = scenario.input
            let engine = PerformanceDecisionEngine()
            let decision = engine.candidate(for: input.snapshot(at: 0))
            XCTAssertEqual(decision.metric, .idle, scenario.rawValue)
            XCTAssertEqual(resolve(input.brightness), .brightness(expected), scenario.rawValue)
        }
    }

    func testSyntheticNeutralIsUnavailableBrightnessAndIdle() {
        let input = AdaptiveRingSyntheticScenario.neutral.input
        XCTAssertEqual(input.brightness, .unavailable)
        XCTAssertEqual(PerformanceDecisionEngine().candidate(for: input.snapshot(at: 0)).metric, .idle)
        XCTAssertEqual(resolve(input.brightness), .neutral)
        XCTAssertEqual(AdaptiveRingVisualTarget(state: .neutral).progress, 0.25)
    }

    func testBrightnessDiagnosticClassifiesPublicPipelineFailures() {
        let valid = diagnosticParameter(result: 0, value: 0.6, valid: true)
        let readFailure = diagnosticParameter(result: -536_870_212, value: nil, valid: false)
        let invalid = diagnosticParameter(result: 0, value: 1.2, valid: false)

        XCTAssertEqual(
            diagnosticFailure(framebuffers: 0, selection: .noMatch),
            .framebufferEnumeration
        )
        XCTAssertEqual(
            diagnosticFailure(mainMetadataUsable: false, selection: .noMatch),
            .mainDisplayMetadata
        )
        XCTAssertEqual(
            diagnosticFailure(selection: .noMatch),
            .displayIdentityMatch
        )
        XCTAssertEqual(
            diagnosticFailure(selection: .ambiguousMatch),
            .ambiguousDisplayMatch
        )
        XCTAssertEqual(
            diagnosticFailure(selection: .uniqueMatch, displayServiceResolved: false),
            .displayServiceResolution
        )
        XCTAssertEqual(
            DisplayBrightnessDiagnostic.resolvedSource(
                availability: .available(0.6),
                standardBrightness: valid,
                linearBrightness: .notAttempted
            ),
            .standard
        )
        XCTAssertEqual(
            DisplayBrightnessDiagnostic.resolvedSource(
                availability: .available(0.6),
                standardBrightness: readFailure,
                linearBrightness: valid
            ),
            .linear
        )
        XCTAssertEqual(
            diagnosticFailure(selection: .uniqueMatch, standard: invalid, linear: readFailure),
            .invalidBrightnessValue
        )
        XCTAssertEqual(
            diagnosticFailure(selection: .uniqueMatch, standard: readFailure, linear: readFailure),
            .standardBrightnessRead
        )
    }

    func testSyntheticPerformanceInputsUseProductionEngineCandidates() {
        let scenarios: [(AdaptiveRingSyntheticScenario, PerformanceMetric, PerformanceSeverity)] = [
            (.cpuModerate, .cpu, .elevated), (.cpuHigh, .cpu, .serious), (.cpuVeryHigh, .cpu, .serious),
            (.memoryPressure, .memory, .serious), (.memoryCritical, .memory, .critical),
            (.thermalSerious, .thermal, .serious), (.thermalCritical, .thermal, .critical)
        ]
        for (scenario, metric, severity) in scenarios {
            let candidate = PerformanceDecisionEngine().candidate(for: scenario.input.snapshot(at: 0))
            XCTAssertEqual(candidate.metric, metric, scenario.rawValue)
            XCTAssertEqual(candidate.severity, severity, scenario.rawValue)
        }
    }

    func testSyntheticCPUHighActivatesThroughPersistencePipeline() {
        var engine = PerformanceDecisionEngine()
        let input = AdaptiveRingSyntheticScenario.cpuHigh.input
        _ = engine.update(with: input.snapshot(at: 0))
        _ = engine.update(with: input.snapshot(at: 2))
        let decision = engine.update(with: input.snapshot(at: 4))
        XCTAssertEqual(decision.activeMetric, .cpu)
        XCTAssertEqual(resolve(input.brightness, performance: decision), .performance(metric: .cpu, value: 0.86))
    }

    func testSyntheticSequenceUsesCoordinatorAuthoritativeDecisionPath() {
        let cpu = AdaptiveRingSyntheticSequence.brightnessCPU.steps[1]
        XCTAssertEqual(resolve(cpu.brightness, performance: cpu.decision), .performance(metric: .cpu, value: 0.86))
        let memory = AdaptiveRingSyntheticSequence.escalation.steps[2]
        XCTAssertEqual(resolve(memory.brightness, performance: memory.decision), .performance(metric: .memory, value: 1))
        let thermal = AdaptiveRingSyntheticSequence.escalation.steps[3]
        XCTAssertEqual(resolve(thermal.brightness, performance: thermal.decision), .performance(metric: .thermal, value: 1))
    }

    @MainActor
    func testSyntheticToLiveClearsMonitorDebugInput() {
        let monitor = AdaptiveRingMonitor()
        monitor.useDebugSyntheticScenario(.thermalCritical)
        XCTAssertEqual(monitor.debugTestSource, .synthetic)
        XCTAssertEqual(monitor.performanceDecision.activeMetric, .thermal)
        monitor.clearDebugSyntheticInput()
        XCTAssertEqual(monitor.debugTestSource, .live)
        XCTAssertNil(monitor.debugScenarioLabel)
    }

    @MainActor
    func testVisualLabStaticScenarioPreservesEngineForChallengerAndReleaseTiming() {
        let monitor = AdaptiveRingMonitor(brightnessReader: TestBrightnessReader())
        monitor.useDebugSyntheticInput(AdaptiveRingSyntheticScenario.cpuHigh.input, label: "CPU High", preference: .automatic)
        let startedAt = try! XCTUnwrap(monitor.performanceSnapshot?.timestamp)
        monitor.refresh(at: startedAt + 4)
        XCTAssertEqual(monitor.performanceDecision.activeMetric, .cpu)
        let generation = monitor.debugEngineGeneration

        monitor.useDebugSyntheticInput(AdaptiveRingSyntheticScenario.memoryPressure.input.with(cpuLoad: 0.86), label: "CPU + Memory", preference: .memory, at: startedAt + 4)
        XCTAssertEqual(monitor.debugEngineGeneration, generation)
        XCTAssertEqual(monitor.performanceDecision.activeMetric, .cpu)
        monitor.refresh(at: startedAt + 12)
        XCTAssertEqual(monitor.performanceDecision.activeMetric, .cpu)
        monitor.refresh(at: startedAt + 17)
        XCTAssertEqual(monitor.performanceDecision.activeMetric, .memory)

        monitor.useDebugSyntheticInput(AdaptiveRingSyntheticScenario.neutral.input, label: "Neutral", preference: .memory, at: startedAt + 17)
        XCTAssertEqual(monitor.performanceDecision.activeMetric, .memory)
        monitor.refresh(at: startedAt + 22)
        XCTAssertEqual(monitor.performanceDecision.activeMetric, .memory)
        monitor.refresh(at: startedAt + 25)
        XCTAssertEqual(monitor.performanceDecision.activeMetric, .idle)
    }

    @MainActor
    func testVisualLabCriticalOverridesPreservedCPUAndResetChangesGeneration() {
        let monitor = AdaptiveRingMonitor(brightnessReader: TestBrightnessReader())
        monitor.useDebugSyntheticInput(AdaptiveRingSyntheticScenario.cpuHigh.input, label: "CPU", preference: .automatic)
        let startedAt = try! XCTUnwrap(monitor.performanceSnapshot?.timestamp)
        monitor.refresh(at: startedAt + 4)
        XCTAssertEqual(monitor.performanceDecision.activeMetric, .cpu)
        let generation = monitor.debugEngineGeneration

        monitor.useDebugSyntheticInput(AdaptiveRingSyntheticScenario.thermalCritical.input.with(cpuLoad: 0.86), label: "Thermal", preference: .automatic, at: startedAt + 4)
        XCTAssertEqual(monitor.debugEngineGeneration, generation)
        XCTAssertEqual(monitor.performanceDecision.activeMetric, .thermal)
        XCTAssertTrue(monitor.performanceDecision.isCriticalOverride)

        monitor.resetDebugSimulation(input: AdaptiveRingSyntheticScenario.neutral.input, label: "Neutral", preference: .automatic, at: startedAt + 4)
        XCTAssertGreaterThan(monitor.debugEngineGeneration, generation)
        XCTAssertEqual(monitor.performanceDecision.activeMetric, .idle)
    }

    @MainActor
    func testLivePreferenceUpdatePreservesSyntheticEngineState() {
        let monitor = AdaptiveRingMonitor(brightnessReader: TestBrightnessReader())
        monitor.useDebugSyntheticInput(AdaptiveRingSyntheticScenario.cpuHigh.input, label: "CPU", preference: .automatic)
        let startedAt = try! XCTUnwrap(monitor.performanceSnapshot?.timestamp)
        monitor.refresh(at: startedAt + 4)
        let generation = monitor.debugEngineGeneration
        monitor.setPreference(.memory)
        XCTAssertEqual(monitor.debugEngineGeneration, generation)
        XCTAssertEqual(monitor.performanceDecision.activeMetric, .cpu)
    }

    private func diagnosticParameter(result: Int32, value: Double?, valid: Bool) -> DisplayBrightnessParameterDiagnostic {
        DisplayBrightnessParameterDiagnostic(
            attempted: true,
            ioReturn: result,
            value: value,
            isValid: valid
        )
    }

    private func diagnosticFailure(
        framebuffers: Int = 1,
        mainMetadataUsable: Bool = true,
        selection: DisplayBrightnessIdentitySelection,
        displayServiceResolved: Bool? = true,
        standard: DisplayBrightnessParameterDiagnostic = .notAttempted,
        linear: DisplayBrightnessParameterDiagnostic = .notAttempted
    ) -> DisplayBrightnessFailureStage {
        DisplayBrightnessDiagnostic.classifyFailure(
            framebufferCount: framebuffers,
            mainDisplayMetadataIsUsable: mainMetadataUsable,
            selection: selection,
            displayServiceResolved: displayServiceResolved,
            standardBrightness: standard,
            linearBrightness: linear
        )
    }
    #endif

    func testPresentationTransitionDirectionsAndTimings() {
        let cpu = AdaptiveRingState.performance(metric: .cpu, value: 0.72)

        XCTAssertEqual(
            AdaptiveRingPresentation.transition(from: .neutral, to: cpu),
            AdaptiveRingPresentationTransition(kind: .performanceTakeover, duration: 0.50)
        )
        XCTAssertEqual(
            AdaptiveRingPresentation.transition(from: cpu, to: .neutral),
            AdaptiveRingPresentationTransition(kind: .baselineRelease, duration: 0.60)
        )
        XCTAssertEqual(
            AdaptiveRingPresentation.transition(from: .brightness(0.6), to: cpu).kind,
            .performanceTakeover
        )
        XCTAssertEqual(
            AdaptiveRingPresentation.transition(from: cpu, to: .brightness(0.6)).kind,
            .baselineRelease
        )
    }

    func testPerformanceValueUpdatesRetargetWithoutAnimatingNoOps() {
        XCTAssertEqual(
            AdaptiveRingPresentation.transition(
                from: .performance(metric: .cpu, value: 0.6),
                to: .performance(metric: .cpu, value: 0.75)
            ),
            AdaptiveRingPresentationTransition(kind: .performanceValueUpdate, duration: 0.40)
        )
        XCTAssertEqual(
            AdaptiveRingPresentation.transition(
                from: .performance(metric: .cpu, value: 0.6),
                to: .performance(metric: .cpu, value: 0.603)
            ),
            .none
        )
    }

    func testMetricChangeUsesTakeoverPresentation() {
        XCTAssertEqual(
            AdaptiveRingPresentation.transition(
                from: .performance(metric: .cpu, value: 0.7),
                to: .performance(metric: .memory, value: 0.8)
            ),
            AdaptiveRingPresentationTransition(kind: .performanceMetricChange, duration: 0.45)
        )
    }

    func testMetricIdentificationRespectsHigherPriorityAudioEvent() {
        XCTAssertEqual(
            AdaptiveRingPresentation.metricToIdentify(
                from: .idle,
                to: .cpu,
                hasHigherPriorityEvent: false
            ),
            .cpu
        )
        XCTAssertNil(
            AdaptiveRingPresentation.metricToIdentify(
                from: .idle,
                to: .cpu,
                hasHigherPriorityEvent: true
            )
        )
        XCTAssertNil(
            AdaptiveRingPresentation.metricToIdentify(
                from: .cpu,
                to: .cpu,
                hasHigherPriorityEvent: false
            )
        )
        XCTAssertNil(
            AdaptiveRingPresentation.metricToIdentify(
                from: .cpu,
                to: .idle,
                hasHigherPriorityEvent: false
            )
        )
    }

    func testAdaptiveSourcePresentationUsesIdentityChangesAndProtectsEntry() {
        XCTAssertTrue(
            AdaptiveSourcePresentationPolicy.shouldPresent(
                from: .neutral,
                to: .brightness,
                isAdaptiveEntryPresenting: false,
                hasHigherPriorityEvent: false
            )
        )
        XCTAssertFalse(
            AdaptiveSourcePresentationPolicy.shouldPresent(
                from: .brightness,
                to: .brightness,
                isAdaptiveEntryPresenting: false,
                hasHigherPriorityEvent: false
            )
        )
        XCTAssertTrue(
            AdaptiveSourcePresentationPolicy.shouldPresent(
                from: .brightness,
                to: .cpu,
                isAdaptiveEntryPresenting: false,
                hasHigherPriorityEvent: false
            )
        )
        XCTAssertTrue(
            AdaptiveSourcePresentationPolicy.shouldPresent(
                from: .cpu,
                to: .memory,
                isAdaptiveEntryPresenting: false,
                hasHigherPriorityEvent: false
            )
        )
        XCTAssertTrue(
            AdaptiveSourcePresentationPolicy.shouldPresent(
                from: .memory,
                to: .thermal,
                isAdaptiveEntryPresenting: false,
                hasHigherPriorityEvent: false
            )
        )
        XCTAssertFalse(
            AdaptiveSourcePresentationPolicy.shouldPresent(
                from: .thermal,
                to: .neutral,
                isAdaptiveEntryPresenting: false,
                hasHigherPriorityEvent: false
            )
        )
        XCTAssertFalse(
            AdaptiveSourcePresentationPolicy.shouldPresent(
                from: .neutral,
                to: .brightness,
                isAdaptiveEntryPresenting: true,
                hasHigherPriorityEvent: false
            )
        )
        XCTAssertEqual(AdaptiveSourcePresentationPolicy.duration, 1.35)
    }

    func testReduceMotionMakesRingPresentationImmediate() {
        let transition = AdaptiveRingPresentation.transition(
            from: .neutral,
            to: .performance(metric: .thermal, value: 0.82)
        )
        XCTAssertEqual(transition.effectiveDuration(animationsEnabled: true, reduceMotion: true), 0)
        XCTAssertEqual(transition.effectiveDuration(animationsEnabled: false, reduceMotion: false), 0)
        XCTAssertEqual(transition.effectiveDuration(animationsEnabled: true, reduceMotion: false), 0.50)
    }

    func testDiagnosticFormattingNeverShowsNeutralAsSamplingOrPercentage() {
        XCTAssertEqual(
            AdaptiveRingDiagnosticFormatter.visualTarget(.neutral),
            "Neutral baseline · 25.0%"
        )
        XCTAssertEqual(
            AdaptiveRingDiagnosticFormatter.visualTarget(.brightness(0.63)),
            "Brightness · 63.0%"
        )
        XCTAssertEqual(
            AdaptiveRingDiagnosticFormatter.visualTarget(.performance(metric: .memory, value: 0.8)),
            "Memory · 80.0%"
        )
    }

    func testEveryAdaptiveStateMapsToOneNormalizedVisualProgress() {
        XCTAssertEqual(AdaptiveRingVisualTarget(state: .neutral).progress, 0.25)
        XCTAssertEqual(AdaptiveRingVisualTarget(state: .brightness(0.65)).progress, 0.65)
        XCTAssertEqual(
            AdaptiveRingVisualTarget(state: .performance(metric: .cpu, value: 0.82)).progress,
            0.82
        )
        XCTAssertEqual(AdaptiveRingVisualTarget(state: .brightness(1.2)).progress, 1)
        XCTAssertEqual(AdaptiveRingVisualTarget(state: .brightness(-0.2)).progress, 0)
    }

    func testColorResolverKeepsBaselineMonochromeAndUsesMetricRoles() {
        let cpu = colorDecision(.cpu, severity: .elevated)
        XCTAssertEqual(AdaptiveRingColorResolver.resolve(state: .brightness(0.7), decision: cpu, colorCodingEnabled: true).role, .brightness)
        XCTAssertEqual(AdaptiveRingColorResolver.resolve(state: .neutral, decision: .idle, colorCodingEnabled: true).role, .monochrome)
        XCTAssertEqual(AdaptiveRingColorResolver.resolve(state: .performance(metric: .cpu, value: 0.7), decision: cpu, colorCodingEnabled: false).role, .monochrome)
        XCTAssertEqual(AdaptiveRingColorResolver.resolve(state: .performance(metric: .cpu, value: 0.7), decision: cpu, colorCodingEnabled: true).role, .cpu)
        XCTAssertEqual(AdaptiveRingColorResolver.resolve(state: .performance(metric: .memory, value: 0.8), decision: colorDecision(.memory, severity: .serious), colorCodingEnabled: true).role, .memory)
        XCTAssertEqual(AdaptiveRingColorResolver.resolve(state: .performance(metric: .thermal, value: 1), decision: colorDecision(.thermal, severity: .critical), colorCodingEnabled: true).role, .thermal)
    }

    func testColorIntensityConsumesEngineSeverity() {
        XCTAssertEqual(AdaptiveRingColorResolver.intensity(for: .elevated), 0.68)
        XCTAssertEqual(AdaptiveRingColorResolver.intensity(for: .serious), 0.82)
        XCTAssertEqual(AdaptiveRingColorResolver.intensity(for: .critical), 1)
    }

    func testAdaptiveRingSettingsDefaultsAndPersistValues() {
        let suite = "DuoBarTests.AdaptiveRingSettings.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        XCTAssertEqual(
            PerformancePreference(rawValue: defaults.string(forKey: PreferenceKeys.adaptiveRingPriority) ?? "") ?? .automatic,
            .automatic
        )
        XCTAssertFalse(defaults.bool(forKey: PreferenceKeys.adaptiveRingColorCoding))

        defaults.set(PerformancePreference.memory.rawValue, forKey: PreferenceKeys.adaptiveRingPriority)
        defaults.set(true, forKey: PreferenceKeys.adaptiveRingColorCoding)
        XCTAssertEqual(PerformancePreference(rawValue: defaults.string(forKey: PreferenceKeys.adaptiveRingPriority)!), .memory)
        XCTAssertTrue(defaults.bool(forKey: PreferenceKeys.adaptiveRingColorCoding))
    }

    func testProductionSettingsEligibilityUsesRealDeviceBehavior() {
        XCTAssertTrue(AdaptiveRingSettingsEligibility.isEligible(for: DeviceContext(hasInternalBattery: true)))
        XCTAssertTrue(AdaptiveRingSettingsEligibility.isEligible(for: DeviceContext(hasInternalBattery: false)))
    }

    func testAdaptiveEntryCenterPolicyTriggersOnlyAcrossModeBoundaryAndCanRepeat() {
        XCTAssertTrue(AdaptiveEntryCenterPolicy.shouldRequest(from: .battery, to: .adaptive))
        XCTAssertFalse(AdaptiveEntryCenterPolicy.shouldRequest(from: .adaptive, to: .adaptive))
        XCTAssertFalse(AdaptiveEntryCenterPolicy.shouldRequest(from: .battery, to: .battery))
        XCTAssertFalse(AdaptiveEntryCenterPolicy.shouldRequest(from: .adaptive, to: .battery))
        XCTAssertEqual(AdaptiveEntryCenterPolicy.duration, 1.35)

        let modes: [LaptopRingMode] = [.battery, .adaptive, .adaptive, .battery, .adaptive]
        let triggers = zip(modes, modes.dropFirst()).filter {
            AdaptiveEntryCenterPolicy.shouldRequest(from: $0.0, to: $0.1)
        }
        XCTAssertEqual(triggers.count, 2)
    }

    func testAdaptiveEntryCenterDefersToExistingNonChargingStatusEvents() {
        XCTAssertTrue(AdaptiveEntryCenterPolicy.allows(over: nil))
        XCTAssertTrue(AdaptiveEntryCenterPolicy.allows(over: StatusEvent(kind: .charging, priority: .informational)))
        XCTAssertFalse(AdaptiveEntryCenterPolicy.allows(over: StatusEvent(kind: .networkDisconnected, priority: .attention)))
        XCTAssertFalse(AdaptiveEntryCenterPolicy.allows(over: StatusEvent(kind: .lowBattery, priority: .critical)))
        let airPods = DebugAudioDeviceState.airPods.status.defaultOutput!
        XCTAssertFalse(AdaptiveEntryCenterPolicy.allows(over: StatusEvent(kind: .audioDeviceConnected(airPods), priority: .informational)))
    }

    #if DEBUG
    func testDebugSettingsEligibilityHonorsDesktopSimulationWithoutSeparatePreferences() {
        let macBook = DeviceContext(hasInternalBattery: true)
        XCTAssertTrue(AdaptiveRingSettingsEligibility.isEligible(for: macBook, simulateDesktop: false))
        XCTAssertTrue(AdaptiveRingSettingsEligibility.isEligible(for: macBook, simulateDesktop: true))
        XCTAssertEqual(PreferenceKeys.adaptiveRingColorCoding, "adaptiveRingColorCoding")
        XCTAssertEqual(PreferenceKeys.adaptiveRingPriority, "adaptiveRingPriority")
    }
    #endif

    func testPresentationStateRetargetsProgressWithoutResettingForSemanticChanges() {
        var presentation = AdaptiveRingPresentationState(state: .neutral)
        XCTAssertEqual(presentation.displayedProgress, 0.25)

        XCTAssertEqual(
            presentation.retarget(to: .performance(metric: .cpu, value: 0.72)).kind,
            .performanceTakeover
        )
        XCTAssertEqual(presentation.displayedProgress, 0.72)

        XCTAssertEqual(
            presentation.retarget(to: .performance(metric: .memory, value: 0.74)).kind,
            .performanceMetricChange
        )
        XCTAssertEqual(presentation.displayedProgress, 0.74)

        XCTAssertEqual(
            presentation.retarget(to: .brightness(0.70)).kind,
            .baselineRelease
        )
        XCTAssertEqual(presentation.displayedProgress, 0.70)
    }

    func testMidAnimationRetargetUsesNewestTargetWithoutAQueuedReset() {
        var presentation = AdaptiveRingPresentationState(state: .neutral)
        _ = presentation.retarget(to: .performance(metric: .cpu, value: 0.72))
        _ = presentation.retarget(to: .performance(metric: .cpu, value: 0.88))
        let transition = presentation.retarget(to: .performance(metric: .cpu, value: 0.61))

        XCTAssertEqual(transition.kind, .performanceValueUpdate)
        XCTAssertEqual(presentation.displayedProgress, 0.61)
        XCTAssertEqual(
            presentation.adaptiveState,
            .performance(metric: .cpu, value: 0.61)
        )
    }

    @MainActor
    func testMonitorUsesOneLeaseAndTimerPerOwner() {
        let monitor = AdaptiveRingMonitor()
        let owner = UUID()
        monitor.acquire(owner: owner, interval: 60)
        monitor.acquire(owner: owner, interval: 60)
        XCTAssertTrue(monitor.isMonitoring)
        XCTAssertEqual(monitor.monitoringOwnerCount, 1)
        monitor.release(owner: owner)
        XCTAssertFalse(monitor.isMonitoring)
        XCTAssertEqual(monitor.monitoringOwnerCount, 0)
    }

    private var display: MainDisplayDescriptor {
        MainDisplayDescriptor(displayID: 1, vendorID: 10, productID: 20, serialNumber: 30)
    }

    private func resolve(
        _ brightness: DisplayBrightnessAvailability,
        performance: PerformanceDecision = .idle
    ) -> AdaptiveRingState {
        coordinator.resolve(
            brightness: DisplayBrightnessSnapshot(
                mainDisplay: display,
                availability: brightness,
                sampledAt: 10
            ),
            performance: performance,
            at: 11
        )
    }

    private func decision(_ metric: PerformanceMetric, value: Double) -> PerformanceDecision {
        PerformanceDecision(
            activeMetric: metric,
            severity: .elevated,
            normalizedRingValue: value,
            reason: .cpuSustained,
            candidate: PerformanceCandidate(
                metric: metric,
                severity: .elevated,
                normalizedValue: value,
                reason: .cpuSustained
            )
        )
    }

    private func colorDecision(_ metric: PerformanceMetric, severity: PerformanceSeverity) -> PerformanceDecision {
        PerformanceDecision(
            activeMetric: metric,
            severity: severity,
            normalizedRingValue: severity.normalizedValue,
            reason: .cpuSustained,
            candidate: PerformanceCandidate(metric: metric, severity: severity, normalizedValue: severity.normalizedValue, reason: .cpuSustained)
        )
    }
}

private struct TestBrightnessReader: DisplayBrightnessReading {
    func readMainDisplay(at timestamp: TimeInterval) -> DisplayBrightnessSnapshot {
        DisplayBrightnessSnapshot(
            mainDisplay: MainDisplayDescriptor(displayID: 1, vendorID: 1, productID: 1, serialNumber: 1),
            availability: .unavailable,
            sampledAt: timestamp
        )
    }
}
