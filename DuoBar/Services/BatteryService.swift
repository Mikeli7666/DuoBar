import Foundation
import IOKit.ps

/// Maps the authoritative internal-battery values returned by IOPowerSources.
///
/// `kIOPSIsChargedKey` is deliberately the only full-charge signal. A displayed
/// 100% is an estimate and must never be promoted to an authoritative full state.
enum BatteryPowerSourceStatusMapper {
    static func status(
        currentCapacity: Int?,
        maximumCapacity: Int?,
        isCharging: Bool,
        powerSourceState: String?,
        isCharged: Bool?,
        lowPowerModeEnabled: Bool
    ) -> BatteryStatus {
        let percentage: Int?
        if let currentCapacity, let maximumCapacity, maximumCapacity > 0 {
            percentage = min(max(Int((Double(currentCapacity) / Double(maximumCapacity) * 100).rounded()), 0), 100)
        } else {
            percentage = nil
        }

        return BatteryStatus(
            percentage: percentage,
            isCharging: isCharging,
            isPluggedIn: powerSourceState == kIOPSACPowerValue,
            isFullyCharged: isCharged == true,
            isAvailable: true,
            isLowPowerModeEnabled: lowPowerModeEnabled
        )
    }
}

@MainActor
final class BatteryService {
    var onStatusChange: ((BatteryStatus) -> Void)?

    private var runLoopSource: CFRunLoopSource?
    private var fallbackTimer: Timer?
    private var lastStatus: BatteryStatus?
    private var lowPowerModeObserver: NSObjectProtocol?

    func start() {
        guard runLoopSource == nil else { return }

        let context = Unmanaged.passUnretained(self).toOpaque()
        let source = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            let service = Unmanaged<BatteryService>.fromOpaque(context).takeUnretainedValue()
            DispatchQueue.main.async {
                #if DEBUG
                NSLog("[BatteryService] power source changed")
                #endif
                service.refresh(trigger: .notification)
            }
        }, context).takeRetainedValue()

        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)

        let fallbackTimer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh(trigger: .fallback)
            }
        }
        self.fallbackTimer = fallbackTimer
        RunLoop.main.add(fallbackTimer, forMode: .common)

        lowPowerModeObserver = NotificationCenter.default.addObserver(
            forName: .NSProcessInfoPowerStateDidChange,
            object: ProcessInfo.processInfo,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refresh(trigger: .lowPowerModeChanged)
            }
        }

        refresh(trigger: .initial)
    }

    func refresh() {
        refresh(trigger: .manual)
    }

    private func refresh(trigger: RefreshTrigger) {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]
        else {
            publish(.unavailable, trigger: trigger)
            return
        }

        let descriptions = sources.compactMap {
            IOPSGetPowerSourceDescription(info, $0)?.takeUnretainedValue() as? [String: Any]
        }
        // Never treat an AC adapter or UPS dictionary as an internal battery.
        guard let dictionary = descriptions.first(where: { $0["Type"] as? String == kIOPSInternalBatteryType }) else {
            publish(.unavailable, trigger: trigger)
            return
        }

        publish(
            BatteryPowerSourceStatusMapper.status(
                currentCapacity: dictionary[kIOPSCurrentCapacityKey] as? Int,
                maximumCapacity: dictionary[kIOPSMaxCapacityKey] as? Int,
                isCharging: dictionary[kIOPSIsChargingKey] as? Bool ?? false,
                powerSourceState: dictionary[kIOPSPowerSourceStateKey] as? String,
                isCharged: dictionary[kIOPSIsChargedKey] as? Bool,
                lowPowerModeEnabled: ProcessInfo.processInfo.isLowPowerModeEnabled
            ),
            trigger: trigger
        )
    }

    private func publish(_ status: BatteryStatus, trigger: RefreshTrigger) {
        let previous = lastStatus
        guard status != previous else { return }
        lastStatus = status

        #if DEBUG
        let percentage = status.percentage.map { "\($0)%" } ?? "unavailable"
        NSLog("%@", "[BatteryService] battery = \(percentage), charging = \(status.isCharging), fullyCharged = \(status.isFullyCharged), pluggedIn = \(status.isPluggedIn), source = \(trigger.rawValue)")
        if let previous, previous.isCharging != status.isCharging {
            NSLog("%@", "[BatteryService] charging changed: \(previous.isCharging) → \(status.isCharging)")
        }
        #endif

        onStatusChange?(status)
    }

    deinit {
        fallbackTimer?.invalidate()
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        if let lowPowerModeObserver {
            NotificationCenter.default.removeObserver(lowPowerModeObserver)
        }
    }

    private enum RefreshTrigger: String {
        case initial
        case notification
        case manual
        case fallback
        case lowPowerModeChanged
    }
}
