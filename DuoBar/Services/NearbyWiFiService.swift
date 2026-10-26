@preconcurrency import CoreWLAN
import Foundation

final class CoreWLANNearbyWiFiProvider: @unchecked Sendable, NearbyWiFiProviding {
    private let client: CWWiFiClient
    private let queue = DispatchQueue(label: "com.mikeli.duobar.nearby-wifi", qos: .userInitiated)
    private var scannedNetworksByID: [String: CWNetwork] = [:]

    init(client: CWWiFiClient = .shared()) {
        self.client = client
    }

    func scan() async throws -> NearbyWiFiScanResult {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [self] in
                do {
                    guard let interface = client.interface() else {
                        throw NearbyWiFiProviderError.interfaceUnavailable
                    }
                    guard interface.powerOn() else {
                        scannedNetworksByID = [:]
                        continuation.resume(returning: NearbyWiFiScanResult(
                            isWiFiPoweredOn: false,
                            networks: []
                        ))
                        return
                    }

                    let currentSSID = SSIDValue.normalized(interface.ssid())
                    let currentBSSID = interface.bssid()?.lowercased()
                    let currentSecurity = interface.security()
                    let scanned = try interface.scanForNetworks(withName: nil)
                    var retained: [String: CWNetwork] = [:]
                    let candidates = scanned.compactMap { network -> NearbyWiFiScanCandidate? in
                        guard let ssid = SSIDValue.normalized(network.ssid) else { return nil }
                        let bssid = network.bssid?.lowercased()
                        let security = Self.security(for: network)
                        let id = Self.identifier(ssid: ssid, bssid: bssid, security: security)
                        retained[id] = network
                        return NearbyWiFiScanCandidate(
                            id: id,
                            ssid: ssid,
                            bssid: bssid,
                            rssi: network.rssiValue,
                            channelNumber: network.wlanChannel?.channelNumber,
                            security: security,
                            isCurrent: currentBSSID != nil
                                ? bssid == currentBSSID
                                : ssid == currentSSID && network.supportsSecurity(currentSecurity)
                        )
                    }
                    scannedNetworksByID = retained
                    continuation.resume(returning: NearbyWiFiScanResult(
                        isWiFiPoweredOn: true,
                        networks: candidates
                    ))
                } catch let error as NearbyWiFiProviderError {
                    continuation.resume(throwing: error)
                } catch {
                    continuation.resume(throwing: NearbyWiFiProviderError.scanFailed)
                }
            }
        }
    }

    func associate(networkID: String, password: String?) async throws {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [self] in
                do {
                    guard let interface = client.interface() else {
                        throw NearbyWiFiProviderError.interfaceUnavailable
                    }
                    guard interface.powerOn() else {
                        throw NearbyWiFiProviderError.wifiOff
                    }
                    guard let network = scannedNetworksByID[networkID] else {
                        throw NearbyWiFiProviderError.networkUnavailable
                    }
                    let security = Self.security(for: network)
                    guard security.supportsDirectAssociation else {
                        throw NearbyWiFiProviderError.associationUnsupported
                    }
                    try interface.associate(
                        to: network,
                        password: security.requiresPassword ? password : nil
                    )
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func identifier(
        ssid: String,
        bssid: String?,
        security: NearbyWiFiSecurity
    ) -> String {
        "\(ssid)|\(security.rawValue)|\(bssid ?? "unknown")"
    }

    private static func security(for network: CWNetwork) -> NearbyWiFiSecurity {
        if network.supportsSecurity(.none) { return .open }

        let enterprise: [CWSecurity] = [
            .dynamicWEP, .wpaEnterprise, .wpaEnterpriseMixed,
            .wpa2Enterprise, .enterprise, .wpa3Enterprise
        ]
        if enterprise.contains(where: network.supportsSecurity) { return .enterprise }

        let personal: [CWSecurity] = [
            .WEP, .wpaPersonal, .wpaPersonalMixed, .wpa2Personal,
            .personal, .wpa3Personal, .wpa3Transition
        ]
        if personal.contains(where: network.supportsSecurity) { return .personal }

        return .unsupported
    }
}
