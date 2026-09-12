import Foundation
import Combine
import IOBluetooth

@MainActor
final class BluetoothService {
    var onStatusChange: ((BluetoothStatus) -> Void)?

    private var observers: [NSObjectProtocol] = []
    private var refreshTimer: Timer?

    func start() {
        guard observers.isEmpty else { return }

        let center = NotificationCenter.default
        let names = [
            Notification.Name.IOBluetoothHostControllerPoweredOn,
            Notification.Name.IOBluetoothHostControllerPoweredOff
        ]

        observers = names.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.refresh()
                }
            }
        }

        refresh()

        let timer = Timer(timeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        refreshTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func refresh() {
        guard let controller = IOBluetoothHostController.default() else {
            onStatusChange?(.unavailable)
            return
        }

        let isPoweredOn = controller.powerState == kBluetoothHCIPowerStateON
        let batteryLevels = isPoweredOn ? AccessoryBatteryReader.batteryLevels() : [:]
        let devices = (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] ?? []).compactMap { device -> PairedBluetoothDevice? in
            guard let address = device.addressString else { return nil }
            return PairedBluetoothDevice(
                id: address,
                name: device.nameOrAddress ?? "Bluetooth device",
                isConnected: isPoweredOn && device.isConnected(),
                batteryPercentage: isPoweredOn && device.isConnected()
                    ? AccessoryBatteryReader.normalizedAddress(address).flatMap { batteryLevels[$0] } : nil
            )
        }.sorted {
            if $0.isConnected != $1.isConnected { return $0.isConnected }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }

        onStatusChange?(
            BluetoothStatus(
                isAvailable: true,
                isPoweredOn: isPoweredOn,
                devices: devices
            )
        )
    }

    deinit {
        refreshTimer?.invalidate()
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    func stop() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        observers.forEach(NotificationCenter.default.removeObserver)
        observers = []
    }
}

@MainActor
final class BluetoothSettingsMonitor: ObservableObject {
    @Published private(set) var status: BluetoothStatus = .unavailable
    private let service = BluetoothService()

    init() {
        service.onStatusChange = { [weak self] in self?.status = $0 }
    }

    func start() { service.start() }
    func stop() { service.stop() }
}
