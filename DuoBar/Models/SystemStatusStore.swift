import Combine
import Foundation

@MainActor
final class SystemStatusStore: ObservableObject {
    @Published private(set) var status: SystemStatus = .unavailable

    let priorityController = StatusPriorityController()

    private let batteryService: BatteryService
    private let wifiService: WiFiService
    private let bluetoothService: BluetoothService

    #if DEBUG
    private var debugBatteryOverride: BatteryStatus?
    private var debugWiFiOverride: WiFiStatus?
    private var debugBluetoothOverride: BluetoothStatus?
    #endif

    init(startServices: Bool = true) {
        batteryService = BatteryService()
        wifiService = WiFiService()
        bluetoothService = BluetoothService()

        batteryService.onStatusChange = { [weak self] value in
            #if DEBUG
            let percentage = value.percentage.map { "\($0)%" } ?? "unavailable"
            NSLog("%@", "[SystemStatusStore] received battery = \(percentage), charging = \(value.isCharging), pluggedIn = \(value.isPluggedIn)")
            guard self?.debugBatteryOverride == nil else { return }
            #endif
            self?.mutate { $0.battery = value }
        }
        wifiService.onStatusChange = { [weak self] value in
            #if DEBUG
            guard self?.debugWiFiOverride == nil else { return }
            #endif
            self?.mutate { $0.wifi = value }
        }
        bluetoothService.onStatusChange = { [weak self] value in
            #if DEBUG
            guard self?.debugBluetoothOverride == nil else { return }
            #endif
            self?.mutate { $0.bluetooth = value }
        }

        if startServices {
            batteryService.start()
            wifiService.start()
            bluetoothService.start()
        }
    }

    func refresh() {
        batteryService.refresh()
        wifiService.refresh()
        bluetoothService.refresh()
    }

    func refreshBluetooth() {
        bluetoothService.refresh()
    }

    func requestWiFiSSIDAccess() {
        wifiService.requestSSIDAccess()
    }

    private func mutate(_ update: (inout SystemStatus) -> Void) {
        let previous = status
        var next = status
        update(&next)
        guard next != previous else { return }

        status = next
        StatusEventDetector.events(from: previous, to: next).forEach(priorityController.present)
    }

    #if DEBUG
    func applyDebugBatteryLevel(_ level: DebugBatteryLevel) {
        var battery = debugBatteryOverride ?? status.battery
        battery.percentage = level.rawValue
        battery.isAvailable = true
        battery.isFullyCharged = level.rawValue == 100 && battery.isPluggedIn && !battery.isCharging
        debugBatteryOverride = battery
        mutate { $0.battery = battery }
    }

    func applyDebugPowerState(_ powerState: DebugPowerState) {
        var battery = debugBatteryOverride ?? status.battery
        if !battery.isAvailable {
            battery = BatteryStatus(
                percentage: 75,
                isCharging: false,
                isPluggedIn: false,
                isFullyCharged: false,
                isAvailable: true
            )
        }
        battery.isCharging = powerState.isCharging
        battery.isPluggedIn = powerState.isCharging
        battery.isFullyCharged = false
        debugBatteryOverride = battery
        mutate { $0.battery = battery }
    }

    func applyDebugWiFiState(_ wifiState: DebugWiFiState) {
        debugWiFiOverride = wifiState.status
        mutate { $0.wifi = wifiState.status }
    }

    func applyDebugBluetoothState(_ bluetoothState: DebugBluetoothState) {
        debugBluetoothOverride = bluetoothState.status
        mutate { $0.bluetooth = bluetoothState.status }
    }

    func restoreLiveStatus() {
        debugBatteryOverride = nil
        debugWiFiOverride = nil
        debugBluetoothOverride = nil
        priorityController.returnToNormal()
        refresh()
    }
    #endif
}
