import AppKit
@preconcurrency import CoreLocation
@preconcurrency import CoreWLAN
import Foundation
@preconcurrency import Network

@MainActor
final class NetworkService: NSObject, @preconcurrency CLLocationManagerDelegate {
    var onStatusChange: ((NetworkStatus) -> Void)?
    var onSSIDAuthorizationChange: ((SSIDAuthorizationState) -> Void)?

    private let client = CWWiFiClient.shared()
    private let wifiPowerCoordinator: WiFiPowerControlCoordinator
    private let locationManager = CLLocationManager()
    private let pathMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.mikeli.duobar.network-monitor", qos: .utility)
    private var latestPath: NWPath?
    private var detailRefreshTimer: Timer?
    private var applicationActivationObserver: NSObjectProtocol?
    #if DEBUG
    private var debugSSIDManualRefreshObserver: NSObjectProtocol?
    #endif
    private var lastStatus: NetworkStatus?
    private var isStarted = false
    private var ssidAccessCoordinator = SSIDAccessCoordinator()

    override init() {
        wifiPowerCoordinator = WiFiPowerControlCoordinator(
            controller: CoreWLANWiFiPowerController(interfaceProvider: { CWWiFiClient.shared().interface() })
        )
        super.init()
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true
        locationManager.delegate = self

        pathMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.latestPath = path
                self?.refresh(reason: .pathChange)
            }
        }
        pathMonitor.start(queue: monitorQueue)

        applicationActivationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: NSApp,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.applicationDidBecomeActive() }
        }

        #if DEBUG
        debugSSIDManualRefreshObserver = NotificationCenter.default.addObserver(
            forName: .debugSSIDManualRefresh,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refresh(reason: .manual) }
        }
        #endif

        // NWPathMonitor supplies immediate connection and interface changes. This
        // low-frequency refresh is only for CoreWLAN details such as changing RSSI.
        let timer = Timer(timeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh(reason: .periodic) }
        }
        detailRefreshTimer = timer
        RunLoop.main.add(timer, forMode: .common)

        refresh(reason: .startup)
    }

    func requestSSIDAccess(trigger: LocationRequestTrigger) {
        performSSIDAccessActions(
            ssidAccessCoordinator.requestAccess(
                authorization: SSIDAuthorizationState(locationManager.authorizationStatus),
                applicationIsActive: NSApp.isActive,
                trigger: trigger
            )
        )
    }

    var currentSSIDAuthorization: SSIDAuthorizationState {
        SSIDAuthorizationState(locationManager.authorizationStatus)
    }

    func refresh() {
        refresh(reason: .manual)
    }

    private func refresh(reason: NetworkRefreshReason) {
        let path = latestPath ?? pathMonitor.currentPath
        let isConnected = path.status == .satisfied
        let activeInterface = preferredInterface(in: path)
        let defaultWiFiInterface = client.interface()
        let wifiInterface = activeInterface?.type == .wifi
            ? client.interface(withName: activeInterface?.name) ?? defaultWiFiInterface
            : defaultWiFiInterface
        let transport = resolvedTransport(
            pathIsConnected: isConnected,
            activeInterface: activeInterface,
            hasWiFiInterface: wifiInterface != nil
        )
        let wifiPoweredOn = wifiInterface?.powerOn()

        var ssid: String?
        var rssi: Int?
        var rawSSID: String?
        if transport == .wifi, let wifiInterface {
            rawSSID = wifiInterface.ssid()
            ssid = SSIDValue.normalized(rawSSID)
            let rawRSSI = wifiInterface.rssiValue()
            rssi = rawRSSI == 0 ? nil : rawRSSI
        }

        let status = NetworkStatus(
            isAvailable: wifiInterface != nil || !path.availableInterfaces.isEmpty,
            isConnected: isConnected,
            transport: transport,
            interfaceName: activeInterface?.name,
            isWiFiPoweredOn: wifiPoweredOn,
            ssid: ssid,
            rssi: rssi
        )
        publish(status)

        #if DEBUG
        SSIDDiagnosticCenter.shared.update(
            SSIDHardwareDiagnostic(
                authorization: SSIDAuthorizationState(locationManager.authorizationStatus),
                applicationIsActive: NSApp.isActive,
                interfaceName: wifiInterface?.interfaceName,
                isWiFiPoweredOn: wifiPoweredOn,
                rawSSID: rawSSID,
                networkStatusSSID: status.ssid,
                pathDescription: pathDescription(path, transport: transport),
                rssi: rssi,
                refreshReason: reason,
                locationRequestAttempted: ssidAccessCoordinator.hasAttemptedAuthorizationRequest,
                locationRequestIssuedWhileActive: ssidAccessCoordinator.wasAuthorizationRequestIssuedWhileActive,
                lastLocationRequestTrigger: ssidAccessCoordinator.lastRequestTrigger
            )
        )
        #endif
    }

    func setWiFiPower(_ enabled: Bool) -> WiFiPowerControlResult {
        let result = wifiPowerCoordinator.setPower(enabled)
        // Re-read the existing sources immediately. NWPathMonitor will still
        // publish any later routing/reconnection transition independently.
        refresh(reason: .wifiPowerChange)
        return result
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        onSSIDAuthorizationChange?(SSIDAuthorizationState(manager.authorizationStatus))
        performSSIDAccessActions(
            ssidAccessCoordinator.authorizationDidChange(
                to: SSIDAuthorizationState(manager.authorizationStatus)
            )
        )
    }

    private func applicationDidBecomeActive() {
        performSSIDAccessActions(
            ssidAccessCoordinator.applicationDidBecomeActive(
                authorization: SSIDAuthorizationState(locationManager.authorizationStatus)
            )
        )
        // A Developer ID/TCC transition can leave the first CoreWLAN read
        // cached as nil. Always re-read on activation so a newly granted
        // Location authorization replaces that stale unavailable value.
        refresh(reason: .manual)
    }

    private func performSSIDAccessActions(_ actions: [SSIDAccessAction]) {
        for action in actions {
            switch action {
            case .requestAuthorization:
                locationManager.requestWhenInUseAuthorization()
                refresh(reason: .authorizationChange)
            case .refresh:
                refresh(reason: .authorizationChange)
            }
        }
    }

    private func preferredInterface(in path: NWPath) -> NWInterface? {
        // Prefer a routed wired path when both Wi-Fi and Ethernet are available.
        // The fallback preserves NWPath's own interface order for other transports.
        path.availableInterfaces.first {
            $0.type == .wiredEthernet && path.usesInterfaceType(.wiredEthernet)
        } ?? path.availableInterfaces.first {
            $0.type == .wifi && path.usesInterfaceType(.wifi)
        } ?? path.availableInterfaces.first { path.usesInterfaceType($0.type) }
    }

    private func resolvedTransport(
        pathIsConnected: Bool,
        activeInterface: NWInterface?,
        hasWiFiInterface: Bool
    ) -> NetworkTransport {
        guard pathIsConnected else { return hasWiFiInterface ? .wifi : .none }
        switch activeInterface?.type {
        case .wifi: return .wifi
        case .wiredEthernet: return .ethernet
        case .some: return .other
        case .none: return .none
        }
    }

    private func publish(_ status: NetworkStatus) {
        guard status != lastStatus else { return }
        lastStatus = status
        onStatusChange?(status)
    }

    #if DEBUG
    private func pathDescription(_ path: NWPath, transport: NetworkTransport) -> String {
        guard path.status == .satisfied else { return "Unsatisfied" }
        switch transport {
        case .wifi: return "Wi-Fi"
        case .ethernet: return "Ethernet"
        case .other: return "Other"
        case .none: return "Unsatisfied"
        }
    }
    #endif

    deinit {
        detailRefreshTimer?.invalidate()
        pathMonitor.cancel()
        if let applicationActivationObserver {
            NotificationCenter.default.removeObserver(applicationActivationObserver)
        }
        #if DEBUG
        if let debugSSIDManualRefreshObserver {
            NotificationCenter.default.removeObserver(debugSSIDManualRefreshObserver)
        }
        #endif
    }
}
