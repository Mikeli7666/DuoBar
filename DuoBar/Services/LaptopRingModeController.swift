import Dispatch
import Foundation

@MainActor
protocol LaptopRingModeScheduledTask: AnyObject {
    func cancel()
}

@MainActor
protocol LaptopRingModeScheduling: AnyObject {
    func schedule(
        after interval: TimeInterval,
        action: @escaping @MainActor () -> Void
    ) -> LaptopRingModeScheduledTask
}

@MainActor
private final class DispatchLaptopRingModeScheduledTask: LaptopRingModeScheduledTask {
    private let workItem: DispatchWorkItem

    init(workItem: DispatchWorkItem) {
        self.workItem = workItem
    }

    func cancel() {
        workItem.cancel()
    }
}

@MainActor
final class DispatchLaptopRingModeScheduler: LaptopRingModeScheduling {
    func schedule(
        after interval: TimeInterval,
        action: @escaping @MainActor () -> Void
    ) -> LaptopRingModeScheduledTask {
        let workItem = DispatchWorkItem {
            Task { @MainActor in action() }
        }
        DispatchQueue.main.asyncAfter(
            deadline: .now() + max(0, interval),
            execute: workItem
        )
        return DispatchLaptopRingModeScheduledTask(workItem: workItem)
    }
}

/// Owns only the MacBook's top-level Battery/Adaptive decision.
/// Battery acquisition, performance intelligence, and rendering deliberately remain elsewhere.
@MainActor
final class LaptopRingModeController {
    private let hasInternalBattery: Bool
    private let scheduler: LaptopRingModeScheduling
    private var fullChargeDelayTask: LaptopRingModeScheduledTask?
    private var fullChargeDelayGeneration = 0
    private var latestBattery: BatteryStatus?
    private var awaitingAuthoritativeFullCharge = false

    private(set) var state: LaptopRingModeState = .battery
    private(set) var fullChargeDelay: LaptopAdaptiveFullChargeDelay
    var onStateChange: ((LaptopRingModeState) -> Void)?

    init(
        hasInternalBattery: Bool,
        fullChargeDelay: LaptopAdaptiveFullChargeDelay = .default,
        scheduler: LaptopRingModeScheduling? = nil
    ) {
        self.hasInternalBattery = hasInternalBattery
        self.fullChargeDelay = fullChargeDelay
        self.scheduler = scheduler ?? DispatchLaptopRingModeScheduler()
    }

    func update(with battery: BatteryStatus) {
        latestBattery = battery

        guard hasInternalBattery else {
            resetForUnplug()
            return
        }

        guard battery.isPluggedIn else {
            resetForUnplug()
            return
        }

        guard let percentage = validatedPercentage(from: battery) else {
            // A missing value must not create a target. Preserve an already unlocked
            // mode while power remains connected, but otherwise return to a safe base state.
            if state.mode != .adaptive {
                cancelFullChargeDelay()
                setState(.battery)
                awaitingAuthoritativeFullCharge = false
            }
            return
        }

        if state.mode == .adaptive {
            return
        }

        if awaitingAuthoritativeFullCharge {
            // Full was previously observed but is no longer authoritative. The prior
            // delayed callback is invalid; wait for a fresh full observation.
            cancelFullChargeDelay()
            return
        }

        if battery.isFullyCharged {
            ensureChargingSession(startingAt: percentage)
            guard let target = state.targetPercentage else { return }
            if target < 100, percentage >= target {
                activateAdaptive()
            } else {
                beginFullChargeDelayIfNeeded()
            }
            return
        }

        guard battery.isCharging else {
            // Optimized charging may pause after a session exists. Before a session
            // exists, a plugged-but-not-charging launch has no reliable baseline.
            return
        }

        ensureChargingSession(startingAt: percentage)
        guard let target = state.targetPercentage else { return }

        // A session whose target is below 100 unlocks as soon as that target is
        // reached, even when the next IOPowerSources snapshot is authoritative
        // full charge and skips the exact percentage notification.
        if target < 100, percentage >= target {
            activateAdaptive()
            return
        }

        if target == 100 {
            awaitingAuthoritativeFullCharge = true
            return
        }
    }

    func setFullChargeDelay(_ delay: LaptopAdaptiveFullChargeDelay) {
        guard fullChargeDelay != delay else { return }
        fullChargeDelay = delay

        guard state.mode == .battery,
              awaitingAuthoritativeFullCharge,
              latestBattery?.isPluggedIn == true,
              latestBattery?.isFullyCharged == true
        else { return }

        cancelFullChargeDelay()
        beginFullChargeDelayIfNeeded()
    }

    private func ensureChargingSession(startingAt percentage: Int) {
        guard state.sessionStartPercentage == nil else { return }

        let requiredGain = percentage < 50 ? 50 : 30
        let target = min(percentage + requiredGain, 100)
        setState(LaptopRingModeState(
            mode: .battery,
            sessionStartPercentage: percentage,
            targetPercentage: target,
            isWaitingForFullChargeDelay: false
        ))
    }

    private func beginFullChargeDelayIfNeeded() {
        awaitingAuthoritativeFullCharge = true
        guard fullChargeDelayTask == nil else { return }

        guard fullChargeDelay != .immediately else {
            activateAdaptive()
            return
        }

        setState(LaptopRingModeState(
            mode: .battery,
            sessionStartPercentage: state.sessionStartPercentage,
            targetPercentage: state.targetPercentage,
            isWaitingForFullChargeDelay: true
        ))

        let generation = fullChargeDelayGeneration
        fullChargeDelayTask = scheduler.schedule(after: fullChargeDelay.timeInterval) { [weak self] in
            self?.completeFullChargeDelay(generation: generation)
        }
    }

    private func completeFullChargeDelay(generation: Int) {
        guard generation == fullChargeDelayGeneration,
              state.mode == .battery,
              awaitingAuthoritativeFullCharge,
              latestBattery?.isPluggedIn == true,
              latestBattery?.isFullyCharged == true
        else { return }
        activateAdaptive()
    }

    private func activateAdaptive() {
        cancelFullChargeDelay()
        awaitingAuthoritativeFullCharge = false
        setState(LaptopRingModeState(
            mode: .adaptive,
            sessionStartPercentage: state.sessionStartPercentage,
            targetPercentage: state.targetPercentage,
            isWaitingForFullChargeDelay: false
        ))
    }

    private func resetForUnplug() {
        cancelFullChargeDelay()
        awaitingAuthoritativeFullCharge = false
        setState(.battery)
    }

    private func cancelFullChargeDelay() {
        fullChargeDelayTask?.cancel()
        fullChargeDelayTask = nil
        fullChargeDelayGeneration &+= 1
        if state.isWaitingForFullChargeDelay {
            setState(LaptopRingModeState(
                mode: state.mode,
                sessionStartPercentage: state.sessionStartPercentage,
                targetPercentage: state.targetPercentage,
                isWaitingForFullChargeDelay: false
            ))
        }
    }

    private func setState(_ next: LaptopRingModeState) {
        guard state != next else { return }
        state = next
        onStateChange?(next)
    }

    private func validatedPercentage(from battery: BatteryStatus) -> Int? {
        guard battery.isAvailable,
              let percentage = battery.percentage,
              (0...100).contains(percentage)
        else { return nil }
        return percentage
    }
}
