import XCTest
@testable import DuoBar

@MainActor
final class LaptopRingModeControllerTests: XCTestCase {
    func testUnpluggedLaunchUsesBatteryMode() {
        let controller = makeController()
        controller.update(with: battery(80))

        XCTAssertEqual(controller.state, .battery)
    }

    func testStartBelowFiftyRequiresFiftyPointGain() {
        let controller = makeController()
        controller.update(with: battery(20, charging: true, plugged: true))

        XCTAssertEqual(controller.state.sessionStartPercentage, 20)
        XCTAssertEqual(controller.state.targetPercentage, 70)
        controller.update(with: battery(69, charging: true, plugged: true))
        XCTAssertEqual(controller.state.mode, .battery)
        controller.update(with: battery(70, charging: true, plugged: true))
        XCTAssertEqual(controller.state.mode, .adaptive)
    }

    func testFortyFiveTargetsNinetyFive() {
        assertTarget(start: 45, target: 95)
    }

    func testFiftyUsesAtOrAboveFiftyRuleAndTargetsEighty() {
        assertTarget(start: 50, target: 80)
    }

    func testFiftyFiveTargetsEightyFive() {
        assertTarget(start: 55, target: 85)
    }

    func testReleasedChargingSessionTargetsCoverAll1_3Boundaries() {
        let immediateTargets: [(start: Int, target: Int)] = [
            (49, 99), (50, 80), (60, 90), (69, 99)
        ]
        for item in immediateTargets {
            let controller = makeController()
            controller.update(with: battery(item.start, charging: true, plugged: true))
            XCTAssertEqual(controller.state.targetPercentage, item.target, "start \(item.start)")
            controller.update(with: battery(item.target, charging: true, plugged: true))
            XCTAssertEqual(controller.state.mode, .adaptive, "target \(item.target)")
        }

        for start in [70, 80, 100] {
            let controller = makeController()
            controller.update(with: battery(start, charging: true, plugged: true))
            XCTAssertEqual(controller.state.targetPercentage, 100, "start \(start)")
            controller.update(with: battery(100, charging: true, plugged: true))
            XCTAssertEqual(controller.state.mode, .battery, "displayed 100 must not unlock start \(start)")
            XCTAssertFalse(controller.state.isWaitingForFullChargeDelay)
            controller.update(with: battery(100, plugged: true, full: true))
            XCTAssertTrue(controller.state.isWaitingForFullChargeDelay, "authoritative full starts delay start \(start)")
        }
    }

    func testSixtyFiveTargetsNinetyFive() {
        assertTarget(start: 65, target: 95)
    }

    func testSeventyFiveClampsTargetToOneHundredAndDoesNotInferFull() {
        let controller = makeController()
        controller.update(with: battery(75, charging: true, plugged: true))
        controller.update(with: battery(100, charging: true, plugged: true))

        XCTAssertEqual(controller.state.targetPercentage, 100)
        XCTAssertEqual(controller.state.mode, .battery)
        XCTAssertFalse(controller.state.isWaitingForFullChargeDelay)
    }

    func testBelowOneHundredTargetActivatesWhenAFullSnapshotSkipsExactTarget() {
        let controller = makeController()
        controller.update(with: battery(49, charging: true, plugged: true))
        XCTAssertEqual(controller.state.targetPercentage, 99)

        controller.update(with: battery(100, charging: true, plugged: true, full: true))

        XCTAssertEqual(controller.state.mode, .adaptive)
        XCTAssertFalse(controller.state.isWaitingForFullChargeDelay)
    }

    func testEightyAndNinetyRequireAuthoritativeFullBeforeDelay() {
        for start in [80, 90] {
            let controller = makeController()
            controller.update(with: battery(start, charging: true, plugged: true))
            controller.update(with: battery(100, charging: true, plugged: true))
            XCTAssertEqual(controller.state.targetPercentage, 100)
            XCTAssertEqual(controller.state.mode, .battery)
            controller.update(with: battery(100, charging: false, plugged: true, full: true))
            XCTAssertTrue(controller.state.isWaitingForFullChargeDelay)
        }
    }

    func testClampedTargetActivatesOnlyAfterAuthoritativeFullAndDelayCompletion() {
        let scheduler = ManualScheduler()
        let controller = makeController(delay: .fiveMinutes, scheduler: scheduler)
        controller.update(with: battery(80, charging: true, plugged: true))
        controller.update(with: battery(100, charging: true, plugged: true))
        XCTAssertEqual(controller.state.mode, .battery)

        controller.update(with: battery(100, plugged: true, full: true))
        scheduler.advance(by: 5 * 60 - 1)
        XCTAssertEqual(controller.state.mode, .battery)
        scheduler.advance(by: 1)
        XCTAssertEqual(controller.state.mode, .adaptive)
    }

    func testFullPluggedLaunchStartsConfiguredDelay() {
        let scheduler = ManualScheduler()
        let controller = makeController(scheduler: scheduler)
        controller.update(with: battery(100, plugged: true, full: true))

        XCTAssertEqual(controller.state.mode, .battery)
        XCTAssertEqual(controller.state.sessionStartPercentage, 100)
        XCTAssertTrue(controller.state.isWaitingForFullChargeDelay)
        scheduler.advance(by: LaptopAdaptiveFullChargeDelay.default.timeInterval - 1)
        XCTAssertEqual(controller.state.mode, .battery)
        scheduler.advance(by: 1)
        XCTAssertEqual(controller.state.mode, .adaptive)
    }

    func testDefaultFullChargeDelayIsFifteenMinutes() {
        XCTAssertEqual(LaptopAdaptiveFullChargeDelay.default, .fifteenMinutes)
        XCTAssertEqual(LaptopAdaptiveFullChargeDelay.default.timeInterval, 15 * 60)
    }

    #if DEBUG
    func testTemporaryDevelopmentHardwareQADelayIsOneMinute() {
        XCTAssertEqual(LaptopAdaptiveFullChargeDelay.oneMinute.timeInterval, 60)
    }
    #endif

    func testImmediateFullChargeDelayActivatesImmediately() {
        let controller = makeController(delay: .immediately)
        controller.update(with: battery(100, plugged: true, full: true))
        XCTAssertEqual(controller.state.mode, .adaptive)
        XCTAssertFalse(controller.state.isWaitingForFullChargeDelay)
    }

    func testEverySupportedDelayedFullChargeChoiceIsHonored() {
        for delay in [.fiveMinutes, .fifteenMinutes, .thirtyMinutes, .oneHour] as [LaptopAdaptiveFullChargeDelay] {
            let scheduler = ManualScheduler()
            let controller = makeController(delay: delay, scheduler: scheduler)
            controller.update(with: battery(100, plugged: true, full: true))
            scheduler.advance(by: delay.timeInterval - 1)
            XCTAssertEqual(controller.state.mode, .battery, "\(delay)")
            scheduler.advance(by: 1)
            XCTAssertEqual(controller.state.mode, .adaptive, "\(delay)")
        }
    }

    func testUnplugDuringDelayCancelsActivationIncludingStaleCallback() {
        let scheduler = ManualScheduler()
        let controller = makeController(scheduler: scheduler)
        controller.update(with: battery(100, plugged: true, full: true))
        controller.update(with: battery(100, full: true))
        scheduler.fireAllIncludingCancelled()

        XCTAssertEqual(controller.state, .battery)
    }

    func testUnplugBeforeTargetResetsSessionAndReplugCreatesNewBaseline() {
        let controller = makeController()
        controller.update(with: battery(20, charging: true, plugged: true))
        controller.update(with: battery(60, charging: true, plugged: true))
        controller.update(with: battery(60))

        XCTAssertEqual(controller.state, .battery)
        controller.update(with: battery(60, charging: true, plugged: true))
        XCTAssertEqual(controller.state.sessionStartPercentage, 60)
        XCTAssertEqual(controller.state.targetPercentage, 90)
    }

    func testUnplugAfterAdaptiveImmediatelyReturnsToBattery() {
        let controller = makeController()
        controller.update(with: battery(50, charging: true, plugged: true))
        controller.update(with: battery(80, charging: true, plugged: true))
        XCTAssertEqual(controller.state.mode, .adaptive)
        controller.update(with: battery(80))
        XCTAssertEqual(controller.state, .battery)
    }

    func testChargingPauseDoesNotResetExistingSession() {
        let controller = makeController()
        controller.update(with: battery(45, charging: true, plugged: true))
        controller.update(with: battery(60, charging: false, plugged: true))

        XCTAssertEqual(controller.state.sessionStartPercentage, 45)
        XCTAssertEqual(controller.state.targetPercentage, 95)
        XCTAssertEqual(controller.state.mode, .battery)
    }

    func testAdaptiveRemainsActiveWhilePluggedAfterChargingAndFullStateChange() {
        let controller = makeController()
        controller.update(with: battery(50, charging: true, plugged: true))
        controller.update(with: battery(80, charging: true, plugged: true))
        controller.update(with: battery(77, plugged: true))

        XCTAssertEqual(controller.state.mode, .adaptive)
    }

    func testAppLaunchWhileChargingUsesCurrentPercentageAsNewBaseline() {
        let controller = makeController()
        controller.update(with: battery(35, charging: true, plugged: true))

        XCTAssertEqual(controller.state.sessionStartPercentage, 35)
        XCTAssertEqual(controller.state.targetPercentage, 85)
    }

    func testSeparateControllersDoNotShareChargingSessionStateAcrossRelaunch() {
        let firstLaunch = makeController()
        firstLaunch.update(with: battery(20, charging: true, plugged: true))

        let relaunched = makeController()
        relaunched.update(with: battery(60, charging: true, plugged: true))

        XCTAssertEqual(relaunched.state.sessionStartPercentage, 60)
        XCTAssertEqual(relaunched.state.targetPercentage, 90)
    }

    func testFullStateDisappearingCancelsDelayAndCannotActivateFromStaleTimer() {
        let scheduler = ManualScheduler()
        let controller = makeController(scheduler: scheduler)
        controller.update(with: battery(100, plugged: true, full: true))
        controller.update(with: battery(100, plugged: true))
        scheduler.fireAllIncludingCancelled()

        XCTAssertEqual(controller.state.mode, .battery)
        XCTAssertFalse(controller.state.isWaitingForFullChargeDelay)
    }

    func testFreshFullObservationAfterTemporaryLossStartsNewDelay() {
        let scheduler = ManualScheduler()
        let controller = makeController(delay: .fiveMinutes, scheduler: scheduler)
        controller.update(with: battery(100, plugged: true, full: true))
        controller.update(with: battery(100, plugged: true))
        controller.update(with: battery(100, plugged: true, full: true))
        scheduler.advance(by: 5 * 60)

        XCTAssertEqual(controller.state.mode, .adaptive)
    }

    func testMissingAndInvalidPercentagesStayBatteryWithoutFabricatedTarget() {
        for status in [
            battery(nil, charging: true, plugged: true, available: false),
            battery(101, charging: true, plugged: true),
            battery(-1, charging: true, plugged: true)
        ] {
            let controller = makeController()
            controller.update(with: status)
            XCTAssertEqual(controller.state, .battery)
        }
    }

    func testDesktopContextNeverUsesLaptopStateMachine() {
        let scheduler = ManualScheduler()
        let controller = LaptopRingModeController(
            hasInternalBattery: false,
            fullChargeDelay: .immediately,
            scheduler: scheduler
        )
        controller.update(with: battery(100, charging: true, plugged: true, full: true))

        XCTAssertEqual(controller.state, .battery)
        XCTAssertEqual(scheduler.scheduledCount, 0)
    }

    func testChangingDelayWhileWaitingRestartsOnlyTheFullChargeDelay() {
        let scheduler = ManualScheduler()
        let controller = makeController(delay: .fifteenMinutes, scheduler: scheduler)
        controller.update(with: battery(100, plugged: true, full: true))
        controller.setFullChargeDelay(.fiveMinutes)
        scheduler.advance(by: 5 * 60)

        XCTAssertEqual(controller.state.mode, .adaptive)
    }

    private func assertTarget(start: Int, target: Int) {
        let controller = makeController()
        controller.update(with: battery(start, charging: true, plugged: true))
        XCTAssertEqual(controller.state.targetPercentage, target)
        controller.update(with: battery(target, charging: true, plugged: true))
        XCTAssertEqual(controller.state.mode, .adaptive)
    }

    private func makeController(
        delay: LaptopAdaptiveFullChargeDelay = .default,
        scheduler: ManualScheduler? = nil
    ) -> LaptopRingModeController {
        LaptopRingModeController(
            hasInternalBattery: true,
            fullChargeDelay: delay,
            scheduler: scheduler ?? ManualScheduler()
        )
    }

    private func battery(
        _ percentage: Int?,
        charging: Bool = false,
        plugged: Bool = false,
        full: Bool = false,
        available: Bool = true
    ) -> BatteryStatus {
        BatteryStatus(
            percentage: percentage,
            isCharging: charging,
            isPluggedIn: plugged,
            isFullyCharged: full,
            isAvailable: available
        )
    }
}

@MainActor
private final class ManualScheduler: LaptopRingModeScheduling {
    private final class ScheduledTask: LaptopRingModeScheduledTask {
        let deadline: TimeInterval
        let action: @MainActor () -> Void
        var isCancelled = false

        init(deadline: TimeInterval, action: @escaping @MainActor () -> Void) {
            self.deadline = deadline
            self.action = action
        }

        func cancel() {
            isCancelled = true
        }
    }

    private var now: TimeInterval = 0
    private var tasks: [ScheduledTask] = []

    var scheduledCount: Int { tasks.count }

    func schedule(after interval: TimeInterval, action: @escaping @MainActor () -> Void) -> LaptopRingModeScheduledTask {
        let task = ScheduledTask(deadline: now + interval, action: action)
        tasks.append(task)
        return task
    }

    func advance(by interval: TimeInterval) {
        now += interval
        let due = tasks.filter { !$0.isCancelled && $0.deadline <= now }
        tasks.removeAll { !$0.isCancelled && $0.deadline <= now }
        due.forEach { $0.action() }
    }

    func fireAllIncludingCancelled() {
        let pending = tasks
        tasks.removeAll()
        pending.forEach { $0.action() }
    }
}
