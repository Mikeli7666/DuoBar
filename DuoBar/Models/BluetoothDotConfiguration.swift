import Foundation

enum BluetoothDotMode: String, CaseIterable, Identifiable {
    case power, connectedCount, pinnedDevices, accessoryBattery

    var id: String { rawValue }
    var title: String {
        switch self {
        case .power: "Bluetooth on/off"
        case .connectedCount: "Connected-device count"
        case .pinnedDevices: "Pinned devices"
        case .accessoryBattery: "Accessory battery"
        }
    }
    var explanation: String {
        switch self {
        case .power: "All four dots brighten when Bluetooth is on."
        case .connectedCount: "One bright dot per connected device. Four means four or more."
        case .pinnedDevices: "Assign one device to each dot, from left to right. It lights up when connected."
        case .accessoryBattery: "Each bright dot represents up to 25% charge. Hollow dots mean no reading is available."
        }
    }
}

struct BluetoothDotConfiguration: Equatable {
    var mode: BluetoothDotMode = .power
    var pinnedDeviceIDs: [String] = []
    var batteryDeviceID = ""

    static let standard = BluetoothDotConfiguration()

    var slots: [String] {
        var seen = Set<String>()
        return (0..<4).map { index in
            guard pinnedDeviceIDs.indices.contains(index) else { return "" }
            let id = pinnedDeviceIDs[index]
            return !id.isEmpty && seen.insert(id).inserted ? id : ""
        }
    }
}

struct BluetoothDotPresentation: Equatable {
    struct Dot: Equatable {
        var opacity: Double
        var isHollow = false
        static let on = Dot(opacity: 1)
        static let off = Dot(opacity: 0.25)
        static let unknown = Dot(opacity: 0.45, isHollow: true)
    }

    let dots: [Dot]
    let summary: String

    init(bluetooth: BluetoothStatus, configuration: BluetoothDotConfiguration) {
        if configuration.mode == .power {
            let opacity = !bluetooth.isAvailable ? 0.14 : (bluetooth.isPoweredOn ? 1.0 : 0.25)
            dots = Array(repeating: Dot(opacity: opacity), count: 4)
            summary = !bluetooth.isAvailable ? "Bluetooth unavailable" : (bluetooth.isPoweredOn ? "Bluetooth on" : "Bluetooth off")
            return
        }
        guard bluetooth.isAvailable, bluetooth.isPoweredOn else {
            dots = Array(repeating: .unknown, count: 4)
            summary = bluetooth.isAvailable ? "Bluetooth off" : "Bluetooth unavailable"
            return
        }
        switch configuration.mode {
        case .power:
            preconditionFailure("Power mode is handled above")
        case .connectedCount:
            let count = Set(bluetooth.devices.filter(\.isConnected).map(\.id)).count
            dots = (0..<4).map { $0 < count ? .on : .off }
            summary = count == 1 ? "1 connected device" : "\(count) connected devices"
        case .pinnedDevices:
            let slots = configuration.slots
            dots = slots.map { id in
                guard !id.isEmpty, let device = bluetooth.devices.first(where: { $0.id == id }) else { return .unknown }
                return device.isConnected ? .on : .off
            }
            summary = slots.enumerated().map { index, id in
                guard !id.isEmpty else { return "Dot \(index + 1): unassigned" }
                guard let device = bluetooth.devices.first(where: { $0.id == id }) else { return "Dot \(index + 1): device unavailable" }
                return "Dot \(index + 1): \(device.name), \(device.isConnected ? "connected" : "disconnected")"
            }.joined(separator: "; ")
        case .accessoryBattery:
            guard !configuration.batteryDeviceID.isEmpty else {
                dots = Array(repeating: .unknown, count: 4)
                summary = "Choose an accessory in DuoBar Settings."
                return
            }
            guard let device = bluetooth.devices.first(where: { $0.id == configuration.batteryDeviceID }) else {
                dots = Array(repeating: .unknown, count: 4)
                summary = "Selected accessory unavailable."
                return
            }
            guard device.isConnected, let percentage = device.batteryPercentage, (0...100).contains(percentage) else {
                dots = Array(repeating: .unknown, count: 4)
                summary = device.isConnected ? "\(device.name): battery reading unavailable." : "\(device.name): disconnected."
                return
            }
            let litCount = (percentage + 24) / 25
            dots = (0..<4).map { $0 < litCount ? .on : .off }
            summary = "\(device.name): \(percentage)% battery"
        }
    }
}
