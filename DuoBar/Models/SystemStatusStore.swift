import Combine
import Foundation

@MainActor
final class SystemStatusStore: ObservableObject {
    @Published private(set) var status: SystemStatus = .unavailable
    @Published private(set) var laptopRingModeState: LaptopRingModeState
    @Published private(set) var wifiPowerControlError: String?

    let priorityController = StatusPriorityController()
    let deviceContext: DeviceContext
    let laptopRingModeController: LaptopRingModeController

    private let batteryService: BatteryService
    private let networkService: NetworkService
    private let audioOutputService: AudioOutputService
    private let bluetoothService: BluetoothService

    #if DEBUG
    private var debugBatteryOverride: BatteryStatus?
    private var debugNetworkOverride: NetworkStatus?
    private var debugAudioOverride: AudioStatus?
    private var debugBluetoothOverride: BluetoothStatus?
    #endif

    init(
        startServices: Bool = true,
        deviceContext: DeviceContext? = nil,
        laptopRingModeController: LaptopRingModeController? = nil
    ) {
        batteryService = BatteryService()
        networkService = NetworkService()
        audioOutputService = AudioOutputService()
        bluetoothService = BluetoothService()
        let resolvedDeviceContext = deviceContext ?? DeviceContextService().current()
        self.deviceContext = resolvedDeviceContext
        let resolvedLaptopRingModeController = laptopRingModeController ?? LaptopRingModeController(
            hasInternalBattery: resolvedDeviceContext.hasInternalBattery
        )
        self.laptopRingModeController = resolvedLaptopRingModeController
        laptopRingModeState = resolvedLaptopRingModeController.state

        resolvedLaptopRingModeController.onStateChange = { [weak self] state in
            self?.laptopRingModeState = state
        }

        batteryService.onStatusChange = { [weak self] value in
            #if DEBUG
            let percentage = value.percentage.map { "\($0)%" } ?? "unavailable"
            NSLog("%@", "[SystemStatusStore] received battery = \(percentage), charging = \(value.isCharging), pluggedIn = \(value.isPluggedIn)")
            guard self?.debugBatteryOverride == nil else { return }
            #endif
            self?.acceptBatteryStatus(value)
        }
        networkService.onStatusChange = { [weak self] value in
            #if DEBUG
            guard self?.debugNetworkOverride == nil else { return }
            #endif
            self?.mutate { $0.network = value }
        }
        audioOutputService.onStatusChange = { [weak self] value in
            #if DEBUG
            guard self?.debugAudioOverride == nil else { return }
            #endif
            self?.mutate { $0.audio = value }
        }
        bluetoothService.onStatusChange = { [weak self] value in
            #if DEBUG
            guard self?.debugBluetoothOverride == nil else { return }
            #endif
            self?.mutate { $0.bluetooth = value }
        }

        if startServices {
            batteryService.start()
            networkService.start()
            audioOutputService.start()
            bluetoothService.start()
        }
    }

    func refresh() {
        batteryService.refresh()
        networkService.refresh()
        audioOutputService.refresh()
        bluetoothService.refresh()
    }

    func requestWiFiSSIDAccess(trigger: LocationRequestTrigger) {
        networkService.requestSSIDAccess(trigger: trigger)
    }

    func setWiFiPower(_ enabled: Bool) {
        #if DEBUG
        guard debugNetworkOverride == nil else { return }
        #endif

        let result = networkService.setWiFiPower(enabled)
        switch result {
        case .success:
            wifiPowerControlError = nil
        case let .failure(_, message):
            wifiPowerControlError = message
            #if DEBUG
            NSLog("%@", "[NetworkService] Wi-Fi power change failed: \(message)")
            #endif
        case .unavailable:
            wifiPowerControlError = localized("Wi-Fi control unavailable")
        }
    }

    var usesAdaptiveRing: Bool {
        deviceContext.ringBehavior == .adaptiveRing || laptopRingModeState.mode == .adaptive
    }

    /// The 1.2 production presentation policy. Laptop Adaptive-after-charging
    /// remains available in the model for 1.3 development, but is intentionally
    /// not eligible to change the released MacBook glyph yet.
    var usesReleasedAdaptiveRing: Bool {
        deviceContext.ringBehavior == .adaptiveRing
    }

    var usesLaptopAdaptiveRing: Bool {
        deviceContext.hasInternalBattery && laptopRingModeState.mode == .adaptive
    }

    @discardableResult
    func setVolume(_ level: Double) -> Bool {
        #if DEBUG
        if var audio = debugAudioOverride {
            guard audio.volume.isSettable else { return false }
            audio.volume.level = min(max(level, 0), 1)
            audio.volume.isMuted = level == 0
            debugAudioOverride = audio
            mutate { $0.audio = audio }
            return true
        }
        #endif
        return audioOutputService.setVolume(level)
    }

    @discardableResult
    func setMuted(_ muted: Bool) -> Bool {
        #if DEBUG
        if var audio = debugAudioOverride {
            guard audio.volume.isMuteSettable else { return false }
            audio.volume.isMuted = muted
            debugAudioOverride = audio
            mutate { $0.audio = audio }
            return true
        }
        #endif
        return audioOutputService.setMuted(muted)
    }

    @discardableResult
    func setDefaultOutput(uid: String) -> Bool {
        #if DEBUG
        if var audio = debugAudioOverride {
            guard let device = audio.selectableOutputs.first(where: { $0.uid == uid }) else {
                return false
            }
            audio.defaultOutput = device
            audio.connectedBluetoothOutputs = audio.selectableOutputs.filter(\.transport.isBluetooth)
            debugAudioOverride = audio
            mutate { $0.audio = audio }
            return true
        }
        #endif
        return audioOutputService.setDefaultOutput(uid: uid)
    }

    private func mutate(_ update: (inout SystemStatus) -> Void) {
        let previous = status
        var next = status
        update(&next)
        guard next != previous else { return }

        status = next
        StatusEventDetector.events(from: previous, to: next).forEach(priorityController.present)
    }

    private func acceptBatteryStatus(_ battery: BatteryStatus) {
        laptopRingModeController.update(with: battery)
        mutate { $0.battery = battery }
    }

    #if DEBUG
    func applyDebugBatteryLevel(_ level: DebugBatteryLevel) {
        var battery = debugBatteryOverride ?? status.battery
        battery.percentage = level.rawValue
        battery.isAvailable = true
        battery.isFullyCharged = level.rawValue == 100 && battery.isPluggedIn && !battery.isCharging
        debugBatteryOverride = battery
        acceptBatteryStatus(battery)
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
        battery.isPluggedIn = powerState.isPluggedIn
        battery.isFullyCharged = powerState.isFullyCharged
        if powerState.isFullyCharged {
            battery.percentage = 100
        }
        debugBatteryOverride = battery
        acceptBatteryStatus(battery)
    }

    func applyDebugLowPowerMode(_ lowPowerMode: DebugLowPowerMode) {
        var battery = debugBatteryOverride ?? status.battery
        if !battery.isAvailable {
            battery = BatteryStatus(
                percentage: 50,
                isCharging: false,
                isPluggedIn: false,
                isFullyCharged: false,
                isAvailable: true
            )
        }
        battery.isLowPowerModeEnabled = lowPowerMode.isEnabled
        debugBatteryOverride = battery
        acceptBatteryStatus(battery)
    }

    func applyDebugBatteryStatus(_ battery: BatteryStatus) {
        debugBatteryOverride = battery
        acceptBatteryStatus(battery)
    }

    func applyDebugNetworkState(_ networkState: DebugNetworkState) {
        debugNetworkOverride = networkState.status
        mutate { $0.network = networkState.status }
    }

    func applyDebugVolumeState(_ volumeState: DebugVolumeState) {
        var audio = debugAudioOverride ?? status.audio
        audio.isAvailable = true
        audio.volume = volumeState.status
        if audio.defaultOutput == nil {
            audio.defaultOutput = DebugAudioDeviceState.builtIn.status.defaultOutput
        }
        debugAudioOverride = audio
        mutate { $0.audio = audio }
    }

    func applyDebugAudioDeviceState(_ deviceState: DebugAudioDeviceState) {
        let audio = deviceState.status
        if deviceState != .builtIn {
            let baseline = DebugAudioDeviceState.builtIn.status
            debugAudioOverride = baseline
            mutate { $0.audio = baseline }
        }
        debugAudioOverride = audio
        mutate { $0.audio = audio }
    }

    func applyDebugBluetoothState(_ bluetoothState: DebugBluetoothState) {
        debugBluetoothOverride = bluetoothState.status
        mutate { $0.bluetooth = bluetoothState.status }
    }

    func restoreLiveStatus() {
        debugBatteryOverride = nil
        debugNetworkOverride = nil
        debugAudioOverride = nil
        debugBluetoothOverride = nil
        priorityController.returnToNormal()
        refresh()
    }

    func applyMarketingCaptureState(_ identifier: String) {
        var battery = BatteryStatus(
            percentage: 75,
            isCharging: false,
            isPluggedIn: false,
            isFullyCharged: false,
            isAvailable: true
        )
        var network = NetworkStatus(
            isAvailable: true,
            isConnected: true,
            transport: .wifi,
            interfaceName: "en0",
            isWiFiPoweredOn: true,
            ssid: "Wi-Fi Network",
            rssi: -42
        )
        let outputDevice = AudioDeviceStatus(
            uid: "marketing-built-in-output",
            name: "MacBook Speakers",
            transport: .builtIn,
            isAlive: true
        )
        var audio = AudioStatus(
            isAvailable: true,
            defaultOutput: outputDevice,
            volume: OutputVolumeStatus(level: 0.75, isMuted: false, isSettable: true, isMuteSettable: true),
            connectedBluetoothOutputs: [],
            availableOutputs: [outputDevice]
        )
        var bluetooth = BluetoothStatus(isAvailable: true, isPoweredOn: true)

        switch identifier {
        case "battery100":
            battery.percentage = 100
        case "battery50":
            battery.percentage = 50
        case "lowBattery":
            battery.percentage = 8
        case "charging":
            battery.percentage = 60
            battery.isCharging = true
            battery.isPluggedIn = true
        case "wifiDisconnected":
            network.isConnected = false
            network.ssid = nil
            network.rssi = nil
        case "bluetoothOff":
            bluetooth.isPoweredOn = false
        case "volumeMuted":
            audio.volume = OutputVolumeStatus(level: 0, isMuted: true, isSettable: true)
        case "hero", "bluetoothOn":
            break
        default:
            return
        }

        debugBatteryOverride = battery
        debugNetworkOverride = network
        debugAudioOverride = audio
        debugBluetoothOverride = bluetooth
        priorityController.returnToNormal()
        laptopRingModeController.update(with: battery)
        mutate {
            $0.battery = battery
            $0.network = network
            $0.audio = audio
            $0.bluetooth = bluetooth
        }
    }
    #endif
}
