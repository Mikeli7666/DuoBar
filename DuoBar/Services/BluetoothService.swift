import Foundation
import IOBluetooth

@MainActor
final class BluetoothService {
    var onStatusChange: ((BluetoothStatus) -> Void)?

    private var observers: [NSObjectProtocol] = []
    private var refreshTimer: Timer?
    private var reportTask: Task<Void, Never>?
    private var generation = UUID()
    private var reports: [String: AccessoryBatteryReader.DeviceReport] = [:]
    private var batteryLevels: [String: Int] = [:]

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
        if !isPoweredOn {
            reports = [:]
            batteryLevels = [:]
            generation = UUID()
            reportTask?.cancel()
            reportTask = nil
        }
        let hasConnectedDevices = publishStatus(isPoweredOn: isPoweredOn, reports: reports, batteryLevels: batteryLevels)
        guard hasConnectedDevices else {
            // The report is used only for connected devices. Keep the cheap
            // connection poll running so newly connected devices refresh on time.
            reports = [:]
            batteryLevels = [:]
            generation = UUID()
            reportTask?.cancel()
            reportTask = nil
            return
        }
        guard reportTask == nil else { return }
        let currentGeneration = generation
        reportTask = Task { [weak self] in
            let snapshot = await Task.detached(priority: .utility) {
                (AccessoryBatteryReader.connectedDeviceReports(), AccessoryBatteryReader.batteryLevels())
            }.value
            guard let self, !Task.isCancelled, self.generation == currentGeneration else { return }
            self.reportTask = nil
            guard let controller = IOBluetoothHostController.default() else { return }
            self.reports = snapshot.0
            self.batteryLevels = snapshot.1
            self.publishStatus(isPoweredOn: controller.powerState == kBluetoothHCIPowerStateON,
                               reports: snapshot.0, batteryLevels: snapshot.1)
        }
    }

    @discardableResult
    private func publishStatus(isPoweredOn: Bool, reports: [String: AccessoryBatteryReader.DeviceReport], batteryLevels: [String: Int]) -> Bool {
        let devices = (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] ?? []).compactMap { device -> PairedBluetoothDevice? in
            guard let address = device.addressString else { return nil }
            let id = AccessoryBatteryReader.normalizedAddress(address) ?? address
            let isConnected = isPoweredOn && device.isConnected()
            let report = isConnected ? reports[id] : nil
            return PairedBluetoothDevice(
                id: address,
                name: report?.name ?? device.name ?? device.nameOrAddress ?? "Bluetooth device",
                isConnected: isConnected,
                batteryPercentage: isConnected
                    ? report?.batteryPercentage ?? batteryLevels[id]
                        ?? AccessoryBatteryReader.headphoneBatteryLevel(device) : nil
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
        return devices.contains(where: \.isConnected)
    }

    deinit {
        reportTask?.cancel()
        refreshTimer?.invalidate()
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    func stop() {
        generation = UUID()
        reportTask?.cancel()
        reportTask = nil
        reports = [:]
        batteryLevels = [:]
        refreshTimer?.invalidate()
        refreshTimer = nil
        observers.forEach(NotificationCenter.default.removeObserver)
        observers = []
    }
}
