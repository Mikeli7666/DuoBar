import Combine
@preconcurrency import CoreWLAN
import Foundation

struct WiFiNetworkOption: Identifiable, Equatable, Sendable {
    enum Security: Sendable {
        case open, personal, systemSettings
    }

    let id: UUID
    let name: String
    let security: Security
    let rssi: Int
}

protocol WiFiControlWorking: Sendable {
    func scan() async throws -> [WiFiNetworkOption]
    func setPower(_ enabled: Bool) async throws
    func join(_ id: UUID, password: String) async throws
}

@MainActor
final class WiFiControls: ObservableObject {
    @Published private(set) var networks: [WiFiNetworkOption] = []
    @Published private(set) var isBusy = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var hasScanned = false
    private let worker: any WiFiControlWorking

    init() { worker = WiFiControlWorker() }

    init(worker: any WiFiControlWorking) { self.worker = worker }

    func scan() async {
        guard !isBusy else { return }
        isBusy = true
        errorMessage = nil
        networks = []
        defer { isBusy = false }
        do {
            networks = try await worker.scan()
            hasScanned = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setPower(_ enabled: Bool) async {
        guard !isBusy else { return }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            try await worker.setPower(enabled)
            networks = []
            hasScanned = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func join(_ network: WiFiNetworkOption, password: String) async -> Bool {
        guard !isBusy else { return false }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            try await worker.join(network.id, password: password)
            return true
        } catch {
            errorMessage = "Could not join \(network.name): \(error.localizedDescription)"
            return false
        }
    }
}

// Scans and association block. Keep CoreWLAN objects on this worker so those
// operations never freeze the popover or cross actor boundaries.
private actor WiFiControlWorker: WiFiControlWorking {
    private var scannedNetworks: [UUID: CWNetwork] = [:]

    private func interface() throws -> CWInterface {
        guard let interface = CWWiFiClient.shared().interface() else {
            throw ControlError.unavailable
        }
        return interface
    }

    func scan() throws -> [WiFiNetworkOption] {
        scannedNetworks = [:]
        let results = try interface().scanForNetworks(withName: nil)
        var options: [WiFiNetworkOption] = []
        // Prefer the strongest access point for each name/security combination.
        for network in results.sorted(by: { $0.rssiValue > $1.rssiValue }) {
            guard let name = network.ssid, !name.isEmpty else { continue }
            let security: WiFiNetworkOption.Security
            if network.supportsSecurity(.none) {
                security = .open
            } else if network.supportsSecurity(.wpaPersonal)
                        || network.supportsSecurity(.wpa2Personal)
                        || network.supportsSecurity(.wpa3Personal)
                        || network.supportsSecurity(.wpa3Transition) {
                security = .personal
            } else {
                security = .systemSettings
            }
            guard !options.contains(where: { $0.name == name && $0.security == security }) else { continue }
            let option = WiFiNetworkOption(id: UUID(), name: name, security: security, rssi: network.rssiValue)
            scannedNetworks[option.id] = network
            options.append(option)
        }
        return options
    }

    func setPower(_ enabled: Bool) throws {
        try interface().setPower(enabled)
        scannedNetworks = [:]
    }

    func join(_ id: UUID, password: String) throws {
        guard let network = scannedNetworks[id] else { throw ControlError.scanAgain }
        try interface().associate(to: network, password: password.isEmpty ? nil : password)
    }

    private enum ControlError: LocalizedError {
        case unavailable, scanAgain
        var errorDescription: String? {
            switch self {
            case .unavailable: "No Wi-Fi interface is available."
            case .scanAgain: "Refresh the network list and try again."
            }
        }
    }
}
