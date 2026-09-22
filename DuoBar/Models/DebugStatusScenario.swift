#if DEBUG
import Foundation

enum DebugBatteryLevel: Int, CaseIterable, Identifiable {
    case full = 100
    case seventyFive = 75
    case half = 50
    case nineteen = 19
    case twenty = 20
    case twentyFive = 25
    case eighty = 80
    case ninetyNine = 99
    case low = 10
    case critical = 5

    var id: Int { rawValue }
    var title: String { "\(rawValue)%" }
}

enum DebugPowerState: String, CaseIterable, Identifiable {
    case charging = "Charging"
    case pluggedPaused = "Plugged / Charging Paused"
    case notCharging = "Not Charging"
    case fullConnected = "Full + Connected"

    var id: String { rawValue }
    var isCharging: Bool { self == .charging }
    var isPluggedIn: Bool { self != .notCharging }
    var isFullyCharged: Bool { self == .fullConnected }
}

enum DebugLowPowerMode: String, CaseIterable, Identifiable {
    case off = "Off"
    case on = "On"

    var id: String { rawValue }
    var isEnabled: Bool { self == .on }
}

enum DebugNetworkState: String, CaseIterable, Identifiable {
    case strong = "Strong"
    case medium = "Medium"
    case weak = "Weak"
    case disconnected = "Disconnected"
    case wifiDisabled = "Wi-Fi Disabled"
    case ethernet = "Ethernet"

    var id: String { rawValue }

    var status: NetworkStatus {
        switch self {
        case .strong:
            wifiStatus(ssid: "Debug Strong", rssi: -42)
        case .medium:
            wifiStatus(ssid: "Debug Medium", rssi: -72)
        case .weak:
            wifiStatus(ssid: "Debug Weak", rssi: -84)
        case .disconnected:
            NetworkStatus(isAvailable: true, isConnected: false, transport: .wifi, interfaceName: "en0", isWiFiPoweredOn: true, ssid: nil, rssi: nil)
        case .wifiDisabled:
            NetworkStatus(isAvailable: true, isConnected: false, transport: .wifi, interfaceName: "en0", isWiFiPoweredOn: false, ssid: nil, rssi: nil)
        case .ethernet:
            NetworkStatus(isAvailable: true, isConnected: true, transport: .ethernet, interfaceName: "en1", isWiFiPoweredOn: true, ssid: nil, rssi: nil)
        }
    }

    private func wifiStatus(ssid: String, rssi: Int) -> NetworkStatus {
        NetworkStatus(isAvailable: true, isConnected: true, transport: .wifi, interfaceName: "en0", isWiFiPoweredOn: true, ssid: ssid, rssi: rssi)
    }
}

enum DebugVolumeState: String, CaseIterable, Identifiable {
    case muted = "Muted"
    case zero = "0%"
    case ten = "10%"
    case twentyFive = "25%"
    case twentySix = "26%"
    case fifty = "50%"
    case fiftyOne = "51%"
    case seventyFive = "75%"
    case seventySix = "76%"
    case full = "100%"
    case controlledByDevice = "Controlled by Device"

    var id: String { rawValue }

    var status: OutputVolumeStatus {
        switch self {
        case .muted: OutputVolumeStatus(level: 0.5, isMuted: true, isSettable: true, isMuteSettable: true)
        case .zero: OutputVolumeStatus(level: 0, isMuted: false, isSettable: true, isMuteSettable: true)
        case .ten: OutputVolumeStatus(level: 0.1, isMuted: false, isSettable: true, isMuteSettable: true)
        case .twentyFive: OutputVolumeStatus(level: 0.25, isMuted: false, isSettable: true, isMuteSettable: true)
        case .twentySix: OutputVolumeStatus(level: 0.26, isMuted: false, isSettable: true, isMuteSettable: true)
        case .fifty: OutputVolumeStatus(level: 0.5, isMuted: false, isSettable: true, isMuteSettable: true)
        case .fiftyOne: OutputVolumeStatus(level: 0.51, isMuted: false, isSettable: true, isMuteSettable: true)
        case .seventyFive: OutputVolumeStatus(level: 0.75, isMuted: false, isSettable: true, isMuteSettable: true)
        case .seventySix: OutputVolumeStatus(level: 0.76, isMuted: false, isSettable: true, isMuteSettable: true)
        case .full: OutputVolumeStatus(level: 1, isMuted: false, isSettable: true, isMuteSettable: true)
        case .controlledByDevice: OutputVolumeStatus(level: 0.5, isMuted: false, isSettable: false)
        }
    }
}

enum DebugAudioDeviceState: String, CaseIterable, Identifiable {
    case builtIn = "MacBook Speakers"
    case airPods = "AirPods Pro"
    case headphones = "Bluetooth Headphones"

    var id: String { rawValue }

    var status: AudioStatus {
        let builtIn = AudioDeviceStatus(
            uid: "debug-MacBook Speakers",
            name: "MacBook Speakers",
            transport: .builtIn,
            isAlive: true,
            terminalType: .other(0)
        )
        let airPods = AudioDeviceStatus(
            uid: "debug-AirPods Pro",
            name: "AirPods Pro",
            transport: .bluetooth,
            isAlive: true,
            modelUID: "2027 4c",
            manufacturer: "Apple Inc.",
            terminalType: .headphones
        )
        let headphones = AudioDeviceStatus(
            uid: "debug-Bluetooth Headphones",
            name: "Bluetooth Headphones",
            transport: .bluetooth,
            isAlive: true,
            terminalType: .headphones
        )
        let selected: AudioDeviceStatus
        switch self {
        case .builtIn: selected = builtIn
        case .airPods: selected = airPods
        case .headphones: selected = headphones
        }
        return AudioStatus(
            isAvailable: true,
            defaultOutput: selected,
            volume: OutputVolumeStatus(level: 0.75, isMuted: false, isSettable: true, isMuteSettable: true),
            connectedBluetoothOutputs: [airPods, headphones],
            availableOutputs: [builtIn, airPods, headphones]
        )
    }
}

enum DebugBluetoothState: String, CaseIterable, Identifiable {
    case on = "On"
    case off = "Off"
    case unavailable = "Unavailable"

    var id: String { rawValue }

    var status: BluetoothStatus {
        switch self {
        case .on:
            BluetoothStatus(isAvailable: true, isPoweredOn: true)
        case .off:
            BluetoothStatus(isAvailable: true, isPoweredOn: false)
        case .unavailable:
            BluetoothStatus(isAvailable: false, isPoweredOn: false)
        }
    }
}
#endif
