import Combine
import Foundation

@MainActor
final class SystemStatusStore: ObservableObject {
    @Published private(set) var status: SystemStatus = .unavailable
    @Published private(set) var laptopRingModeState: LaptopRingModeState
    @Published private(set) var wifiPowerControlError: String?
    @Published private(set) var wifiSSIDAuthorization: SSIDAuthorizationState = .notDetermined

    let priorityController = StatusPriorityController()
    let deviceContext: DeviceContext
    let laptopRingModeController: LaptopRingModeController
    let nearbyWiFiController: NearbyWiFiController

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
        laptopRingModeController: LaptopRingModeController? = nil,
        nearbyWiFiProvider: (any NearbyWiFiProviding)? = nil
    ) {
        batteryService = BatteryService()
        networkService = NetworkService()
        audioOutputService = AudioOutputService()
        bluetoothService = BluetoothService()
        let resolvedDeviceContext = deviceContext ?? DeviceContextService().current()
        self.deviceContext = resolvedDeviceContext
        let resolvedLaptopRingModeController = laptopRingModeController ?? LaptopRingModeController(
            hasInternalBattery: resolvedDeviceContext.hasInternalBattery,
            fullChargeDelay: Self.developmentFullChargeDelay
        )
        self.laptopRingModeController = resolvedLaptopRingModeController
        nearbyWiFiController = NearbyWiFiController(
            provider: nearbyWiFiProvider ?? CoreWLANNearbyWiFiProvider()
        )
        wifiSSIDAuthorization = networkService.currentSSIDAuthorization
        laptopRingModeState = resolvedLaptopRingModeController.state

        resolvedLaptopRingModeController.onStateChange = { [weak self] state in
            guard let self else { return }
            let previous = self.laptopRingModeState
            #if DEBUG
            NSLog(
                "%@",
                "[DuoBar Adaptive QA] LaptopRingMode \(previous.mode) -> \(state.mode); "
                    + "session=\(state.sessionStartPercentage.map(String.init) ?? "nil") "
                    + "target=\(state.targetPercentage.map(String.init) ?? "nil") "
                    + "waiting=\(state.isWaitingForFullChargeDelay)"
            )
            #endif
            self.laptopRingModeState = state
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
        networkService.onSSIDAuthorizationChange = { [weak self] authorization in
            guard let self else { return }
            self.wifiSSIDAuthorization = authorization
            if authorization == .authorized, self.nearbyWiFiController.hasRequestedScan {
                self.nearbyWiFiController.refreshAfterCurrentRequest()
            }
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

    private static let developmentFullChargeDelay: LaptopAdaptiveFullChargeDelay = {
        #if DEBUG
        // TEMPORARY: real-hardware MacBook Adaptive Ring QA. Restore `.default`
        // after the physical full-charge-delay path has been validated.
        return .oneMinute
        #else
        return .default
        #endif
    }()

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

    func scanNearbyWiFiIfNeeded() async {
        requestWiFiSSIDAccess(trigger: .popoverOpened)
        await nearbyWiFiController.scanIfNeeded()
    }

    func refreshNearbyWiFi() async {
        requestWiFiSSIDAccess(trigger: .popoverOpened)
        await nearbyWiFiController.refresh()
    }

    @discardableResult
    func joinNearbyWiFi(_ network: NearbyWiFiNetwork, password: String?) async -> Bool {
        let joined = await nearbyWiFiController.join(network, password: password)
        guard joined else { return false }
        networkService.refresh()
        await nearbyWiFiController.refresh()
        return true
    }

    var usesAdaptiveRing: Bool {
        deviceContext.ringBehavior == .adaptiveRing || laptopRingModeState.mode == .adaptive
    }

    /// The authoritative 1.3 production presentation policy. Desktop systems
    /// are Adaptive by device policy; MacBooks become Adaptive only when the
    /// existing laptop controller has transitioned out of Battery mode.
    var usesReleasedAdaptiveRing: Bool {
        deviceContext.ringBehavior == .adaptiveRing || laptopRingModeState.mode == .adaptive
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

    /// Resets the real controller with its synthetic 50% unplugged baseline
    /// while preserving the battery percentage currently visible in the glyph.
    func applyDebugAdaptiveBatteryBaseline() {
        let controllerBattery = BatteryStatus(
            percentage: DebugBatteryLevel.half.rawValue,
            isCharging: false,
            isPluggedIn: false,
            isFullyCharged: false,
            isAvailable: true
        )
        var visibleBattery = debugVisibleAdaptiveBattery()
        visibleBattery.isCharging = false
        visibleBattery.isPluggedIn = false
        visibleBattery.isFullyCharged = false

        debugBatteryOverride = visibleBattery
        mutate { $0.battery = visibleBattery }
        laptopRingModeController.update(with: controllerBattery)
    }

    /// Prepares the real controller's hidden 50% -> 80% session while only
    /// publishing Charging semantics at the glyph's current visible percentage.
    func applyDebugAdaptiveChargingBaseline() {
        let controllerUnplugged = BatteryStatus(
            percentage: DebugBatteryLevel.half.rawValue,
            isCharging: false,
            isPluggedIn: false,
            isFullyCharged: false,
            isAvailable: true
        )
        let controllerCharging = BatteryStatus(
            percentage: DebugBatteryLevel.half.rawValue,
            isCharging: true,
            isPluggedIn: true,
            isFullyCharged: false,
            isAvailable: true
        )
        var visibleCharging = debugVisibleAdaptiveBattery()
        visibleCharging.isCharging = true
        visibleCharging.isPluggedIn = true
        visibleCharging.isFullyCharged = false

        laptopRingModeController.update(with: controllerUnplugged)
        laptopRingModeController.update(with: controllerCharging)
        debugBatteryOverride = visibleCharging
        mutate { $0.battery = visibleCharging }
    }

    /// Crosses the prepared session target in the real controller while the
    /// menu-bar glyph keeps its stable Charging baseline until mode changes.
    func reachDebugAdaptiveTarget() {
        guard var battery = debugBatteryOverride,
              battery.isCharging,
              battery.isPluggedIn,
              let target = laptopRingModeState.targetPercentage
        else { return }
        battery.percentage = target
        laptopRingModeController.update(with: battery)
    }

    private func debugVisibleAdaptiveBattery() -> BatteryStatus {
        var battery = debugBatteryOverride ?? status.battery
        if !battery.isAvailable || battery.percentage == nil {
            battery.percentage = DebugBatteryLevel.half.rawValue
            battery.isAvailable = true
        }
        return battery
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
        case "ethernet":
            network = DebugNetworkState.ethernet.status
        case "bluetoothOff":
            bluetooth.isPoweredOn = false
        case "volumeMuted":
            audio.volume = OutputVolumeStatus(level: 0, isMuted: true, isSettable: true)
        case "airpodsConnected":
            let airPods = DebugAudioDeviceState.airPods.status.defaultOutput!
            audio.connectedBluetoothOutputs = [airPods]
            audio.availableOutputs = [outputDevice, airPods]
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

        if identifier == "airpodsConnected" {
            if let airPods = audio.connectedBluetoothOutputs.first {
                priorityController.present(
                    StatusEvent(kind: .audioDeviceConnected(airPods), priority: .informational, duration: 30)
                )
            }
        }
    }
    #endif
}
