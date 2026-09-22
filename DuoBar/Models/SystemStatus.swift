import Foundation

struct BatteryStatus: Equatable, Sendable {
    var percentage: Int?
    var isCharging: Bool
    var isPluggedIn: Bool
    var isFullyCharged: Bool
    var isAvailable: Bool
    var isLowPowerModeEnabled = false

    static let unavailable = BatteryStatus(
        percentage: nil,
        isCharging: false,
        isPluggedIn: false,
        isFullyCharged: false,
        isAvailable: false
    )
}

enum NetworkTransport: Equatable, Sendable {
    case wifi
    case ethernet
    case other
    case none
}

struct NetworkStatus: Equatable, Sendable {
    var isAvailable: Bool
    var isConnected: Bool
    var transport: NetworkTransport
    var interfaceName: String?
    var isWiFiPoweredOn: Bool?
    var ssid: String?
    var rssi: Int?

    static let unavailable = NetworkStatus(
        isAvailable: false,
        isConnected: false,
        transport: .none,
        interfaceName: nil,
        isWiFiPoweredOn: nil,
        ssid: nil,
        rssi: nil
    )

    var signalStrength: Double? {
        guard let rssi, rssi < 0 else { return nil }
        return min(max(Double(rssi + 100) / 65.0, 0), 1)
    }

    var wifiSignalLevel: WiFiSignalLevel {
        guard isAvailable else { return .unavailable }
        guard transport == .wifi || !isConnected else { return .unavailable }
        guard isWiFiPoweredOn != false else { return .disabled }
        guard isConnected else { return .disconnected }

        guard let rssi, rssi < 0 else { return .medium }
        if rssi >= -67 { return .strong }
        if rssi >= -75 { return .medium }
        return .weak
    }
}

enum WiFiSignalLevel: Hashable, Sendable {
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

struct OutputVolumeStatus: Equatable, Sendable {
    var level: Double?
    var isMuted: Bool
    var isSettable: Bool
    var isMuteSettable: Bool

    init(level: Double?, isMuted: Bool, isSettable: Bool, isMuteSettable: Bool = false) {
        self.level = level
        self.isMuted = isMuted
        self.isSettable = isSettable
        self.isMuteSettable = isMuteSettable
    }

    static let unavailable = OutputVolumeStatus(
        level: nil,
        isMuted: false,
        isSettable: false,
        isMuteSettable: false
    )

    var percentage: Int? {
        level.map { min(max(Int(($0 * 100).rounded()), 0), 100) }
    }

    var activeDotCount: Int? {
        guard let percentage else { return nil }
        if isMuted || percentage == 0 { return 0 }

        switch percentage {
        case 1...25: return 1
        case 26...50: return 2
        case 51...75: return 3
        default: return 4
        }
    }
}

enum AudioDeviceTransport: Equatable, Sendable {
    case builtIn
    case bluetooth
    case bluetoothLE
    case airPlay
    case usb
    case hdmi
    case displayPort
    case virtual
    case other

    var isBluetooth: Bool {
        self == .bluetooth || self == .bluetoothLE
    }
}

enum AudioDeviceGlyph: Equatable, Sendable {
    case airPods
    case headphones
}

enum AudioConnectionGlyph: Equatable, Sendable {
    case airPodsPro
    case airPodsMax
    case airPods
    case headphones
    case audioDevice
}

enum AudioDeviceTerminalType: Equatable, Sendable {
    case headphones
    case other(UInt32)
    case unavailable
}

struct AudioDeviceStatus: Equatable, Sendable, Identifiable {
    var id: String { uid }

    var uid: String
    var name: String
    var transport: AudioDeviceTransport
    var isAlive: Bool
    var modelUID: String? = nil
    var manufacturer: String? = nil
    var terminalType: AudioDeviceTerminalType = .unavailable

    var temporaryGlyph: AudioDeviceGlyph {
        let normalizedName = name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        return normalizedName.contains("airpods") ? .airPods : .headphones
    }

    var temporaryConnectionGlyph: AudioConnectionGlyph {
        if normalizedModelUID == "2027 4c" {
            return .airPodsPro
        }

        let isBluetoothHeadphones = transport.isBluetooth && terminalType == .headphones
        let isApple = normalizedManufacturer.contains("apple")
        guard isBluetoothHeadphones else {
            return transport.isBluetooth ? .headphones : .audioDevice
        }

        if isApple, normalizedName.contains("airpods pro") {
            return .airPodsPro
        }
        if normalizedName.contains("airpods max") {
            return .airPodsMax
        }
        if normalizedName.contains("airpods") {
            return .airPods
        }
        return .headphones
    }

    private var normalizedName: String {
        name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    private var normalizedManufacturer: String {
        manufacturer?
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current) ?? ""
    }

    private var normalizedModelUID: String {
        modelUID?
            .lowercased()
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ") ?? ""
    }
}

struct AudioStatus: Equatable, Sendable {
    var isAvailable: Bool
    var defaultOutput: AudioDeviceStatus?
    var volume: OutputVolumeStatus
    var connectedBluetoothOutputs: [AudioDeviceStatus]
    var availableOutputs: [AudioDeviceStatus] = []

    static let unavailable = AudioStatus(
        isAvailable: false,
        defaultOutput: nil,
        volume: .unavailable,
        connectedBluetoothOutputs: []
    )

    var connectedAudioDevice: AudioDeviceStatus? {
        if let defaultOutput, defaultOutput.transport.isBluetooth {
            return defaultOutput
        }
        return connectedBluetoothOutputs.first ?? defaultOutput
    }

    var selectableOutputs: [AudioDeviceStatus] {
        var seen = Set<String>()
        var ordered: [AudioDeviceStatus] = []

        let source = availableOutputs.isEmpty
            ? [defaultOutput].compactMap { $0 } + connectedBluetoothOutputs
            : availableOutputs

        for device in source where device.isAlive {
            if seen.insert(device.uid).inserted {
                ordered.append(device)
            }
        }

        if let defaultOutput, defaultOutput.isAlive, seen.insert(defaultOutput.uid).inserted {
            ordered.insert(defaultOutput, at: 0)
        }

        return ordered
    }
}

struct BluetoothStatus: Equatable, Sendable {
    var isAvailable: Bool
    var isPoweredOn: Bool

    static let unavailable = BluetoothStatus(isAvailable: false, isPoweredOn: false)
}

struct SystemStatus: Equatable, Sendable {
    var battery: BatteryStatus
    var network: NetworkStatus
    var audio: AudioStatus
    // Retained until Core Audio connection behavior is validated on real hardware.
    var bluetooth: BluetoothStatus

    static let unavailable = SystemStatus(
        battery: .unavailable,
        network: .unavailable,
        audio: .unavailable,
        bluetooth: .unavailable
    )
}
