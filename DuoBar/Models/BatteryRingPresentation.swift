import Foundation

enum BatteryBoltPlacement: Equatable, Sendable {
    case none
    case topGap
}

enum BatteryRingColorRole: Equatable, Sendable {
    case monochrome
    case charging
    case lowPowerMode
    case lowBattery
}

struct BatteryRingPresentation: Equatable, Sendable {
    let boltPlacement: BatteryBoltPlacement
    let colorRole: BatteryRingColorRole

    static func resolve(
        battery: BatteryStatus,
        colorCodingEnabled: Bool
    ) -> BatteryRingPresentation {
        guard battery.isAvailable else {
            return BatteryRingPresentation(boltPlacement: .none, colorRole: .monochrome)
        }

        // IOPowerSources' authoritative full flag wins over a concurrent or
        // stale charging flag. Fully charged must not retain charging bolt or
        // green charging semantics.
        if battery.isFullyCharged {
            return BatteryRingPresentation(boltPlacement: .none, colorRole: .monochrome)
        }

        let boltPlacement: BatteryBoltPlacement = battery.isPluggedIn ? .topGap : .none

        guard colorCodingEnabled else {
            return BatteryRingPresentation(boltPlacement: boltPlacement, colorRole: .monochrome)
        }

        let colorRole: BatteryRingColorRole
        if battery.isPluggedIn {
            colorRole = .charging
        } else if battery.isLowPowerModeEnabled {
            colorRole = .lowPowerMode
        } else if let percentage = battery.percentage, percentage < 20 {
            colorRole = .lowBattery
        } else {
            colorRole = .monochrome
        }
        return BatteryRingPresentation(boltPlacement: boltPlacement, colorRole: colorRole)
    }
}
