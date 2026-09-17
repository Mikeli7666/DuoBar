import Foundation

struct BatteryStatus: Equatable, Sendable {
    var percentage: Int?
    var isCharging: Bool
    var isPluggedIn: Bool
    var isFullyCharged: Bool
    var isAvailable: Bool

    static let unavailable = BatteryStatus(
        percentage: nil,
        isCharging: false,
        isPluggedIn: false,
        isFullyCharged: false,
        isAvailable: false
    )
}

enum WiFiNameAccess: Equatable, Sendable {
    case unknown, notDetermined, denied, restricted, authorized, servicesDisabled
}

struct WiFiStatus: Equatable, Sendable {
    var isAvailable: Bool
    var isPoweredOn: Bool
    var isConnected: Bool
    var ssid: String?
    var rssi: Int?
    var nameAccess: WiFiNameAccess = .unknown

    static let unavailable = WiFiStatus(
        isAvailable: false,
        isPoweredOn: false,
        isConnected: false,
        ssid: nil,
        rssi: nil
    )

    var signalStrength: Double? {
        guard let rssi, rssi < 0 else { return nil }
        return min(max(Double(rssi + 100) / 65.0, 0), 1)
    }

    var signalLevel: WiFiSignalLevel {
        guard isAvailable else { return .unavailable }
        guard isPoweredOn else { return .disabled }
        guard isConnected else { return .disconnected }

        guard let signalStrength else { return .medium }
        switch signalStrength {
        case 0.67...:
            return .strong
        case 0.34...:
            return .medium
        default:
            return .weak
        }
    }
}

enum WiFiSignalLevel: Equatable, Sendable {
    case strong
    case medium
    case weak
    case disconnected
    case disabled
    case unavailable

    var symbolVariableValue: Double? {
        switch self {
        case .strong: 1
        case .medium: 0.62
        case .weak: 0.25
        case .disconnected, .disabled, .unavailable: nil
        }
    }
}

struct BluetoothStatus: Equatable, Sendable {
    var isAvailable: Bool
    var isPoweredOn: Bool
    var devices: [PairedBluetoothDevice] = []

    static let unavailable = BluetoothStatus(isAvailable: false, isPoweredOn: false)
}

struct SystemStatus: Equatable, Sendable {
    var battery: BatteryStatus
    var wifi: WiFiStatus
    var bluetooth: BluetoothStatus

    // A radio-state indicator, not a separate macOS airplane-mode setting.
    var areWirelessRadiosOff: Bool {
        wifi.isAvailable && bluetooth.isAvailable && !wifi.isPoweredOn && !bluetooth.isPoweredOn
    }

    static let unavailable = SystemStatus(
        battery: .unavailable,
        wifi: .unavailable,
        bluetooth: .unavailable
    )
}
