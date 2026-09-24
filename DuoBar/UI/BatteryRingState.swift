import SwiftUI

enum BatteryRingState: Equatable {
    case unavailable, charging, full, pluggedIn, critical, low, normal

    var color: Color {
        switch self {
        case .unavailable: .secondary
        case .charging, .full, .pluggedIn: .green
        case .normal: .primary
        case .critical: .red
        case .low: .yellow
        }
    }
}

extension BatteryStatus {
    var ringState: BatteryRingState {
        guard isAvailable else { return .unavailable }
        if isCharging { return .charging }
        if isFullyCharged { return .full }
        if isPluggedIn { return .pluggedIn }
        guard let percentage, (0...100).contains(percentage) else { return .unavailable }
        if percentage <= 10 { return .critical }
        if percentage <= 20 { return .low }
        return .normal
    }
}
