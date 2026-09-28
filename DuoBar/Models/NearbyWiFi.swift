import Combine
import Foundation

enum NearbyWiFiSecurity: String, CaseIterable, Sendable {
    case open
    case personal
    case enterprise
    case unsupported

    var requiresPassword: Bool { self == .personal }

    var supportsDirectAssociation: Bool {
        self == .open || self == .personal
    }
}

struct NearbyWiFiScanCandidate: Equatable, Sendable {
    let id: String
    let ssid: String
    let bssid: String?
    let rssi: Int
    let channelNumber: Int?
    let security: NearbyWiFiSecurity
    let isCurrent: Bool
}

struct NearbyWiFiNetwork: Identifiable, Equatable, Sendable {
    let id: String
    let ssid: String
    let rssi: Int
    let security: NearbyWiFiSecurity
    let isCurrent: Bool

    var signalLevel: WiFiSignalLevel {
        if rssi >= -67 { return .strong }
        if rssi >= -75 { return .medium }
        return .weak
    }

    var signalSymbolName: String {
        switch signalLevel {
        case .strong: "wifi"
        case .medium: "wifi"
        case .weak: "wifi"
        case .disconnected, .disabled, .unavailable: "wifi"
        }
    }

    var signalSymbolVariableValue: Double {
        signalLevel.symbolVariableValue ?? 0.5
    }
}

enum NearbyWiFiListBuilder {
    static func makeNetworks(from candidates: [NearbyWiFiScanCandidate]) -> [NearbyWiFiNetwork] {
        var preferredByIdentity: [String: NearbyWiFiScanCandidate] = [:]

        for candidate in candidates {
            guard let ssid = SSIDValue.normalized(candidate.ssid) else { continue }
            let normalized = NearbyWiFiScanCandidate(
                id: candidate.id,
                ssid: ssid,
                bssid: candidate.bssid,
                rssi: candidate.rssi,
                channelNumber: candidate.channelNumber,
                security: candidate.security,
                isCurrent: candidate.isCurrent
            )
            let identity = "\(ssid)|\(candidate.security.rawValue)"

            if let existing = preferredByIdentity[identity] {
                if shouldPrefer(normalized, over: existing) {
                    preferredByIdentity[identity] = normalized
                }
            } else {
                preferredByIdentity[identity] = normalized
            }
        }

        return preferredByIdentity.values
            .map {
                NearbyWiFiNetwork(
                    id: $0.id,
                    ssid: $0.ssid,
                    rssi: $0.rssi,
                    security: $0.security,
                    isCurrent: $0.isCurrent
                )
            }
            .sorted(by: sortBefore)
    }

    private static func shouldPrefer(
        _ candidate: NearbyWiFiScanCandidate,
        over existing: NearbyWiFiScanCandidate
    ) -> Bool {
        if candidate.isCurrent != existing.isCurrent { return candidate.isCurrent }
        if candidate.rssi != existing.rssi { return candidate.rssi > existing.rssi }
        return candidate.id.localizedStandardCompare(existing.id) == .orderedAscending
    }

    private static func sortBefore(_ lhs: NearbyWiFiNetwork, _ rhs: NearbyWiFiNetwork) -> Bool {
        if lhs.isCurrent != rhs.isCurrent { return lhs.isCurrent }
        if lhs.rssi != rhs.rssi { return lhs.rssi > rhs.rssi }
        let nameOrder = lhs.ssid.localizedCaseInsensitiveCompare(rhs.ssid)
        if nameOrder != .orderedSame { return nameOrder == .orderedAscending }
        return lhs.id.localizedStandardCompare(rhs.id) == .orderedAscending
    }
}

struct NearbyWiFiScanResult: Equatable, Sendable {
    let isWiFiPoweredOn: Bool
    let networks: [NearbyWiFiScanCandidate]
}

protocol NearbyWiFiProviding: Sendable {
    func scan() async throws -> NearbyWiFiScanResult
    func associate(networkID: String, password: String?) async throws
}

enum NearbyWiFiState: Equatable, Sendable {
    case idle
    case scanning
    case joining(networkID: String)
    case success(networkID: String)
    case failure(message: String)
}

@MainActor
final class NearbyWiFiController: ObservableObject {
    @Published private(set) var networks: [NearbyWiFiNetwork] = []
    @Published private(set) var state: NearbyWiFiState = .idle
    @Published private(set) var isWiFiPoweredOn: Bool?
    private(set) var hasRequestedScan = false

    private let provider: any NearbyWiFiProviding
    private let cacheDuration: TimeInterval
    private let now: () -> Date
    private var lastSuccessfulScanDate: Date?
    private var requestGeneration: UInt = 0
    private var refreshIsPending = false

    init(
        provider: any NearbyWiFiProviding,
        cacheDuration: TimeInterval = 15,
        now: @escaping () -> Date = Date.init
    ) {
        self.provider = provider
        self.cacheDuration = cacheDuration
        self.now = now
    }

    var isBusy: Bool {
        switch state {
        case .scanning, .joining: true
        case .idle, .success, .failure: false
        }
    }

    func scanIfNeeded() async {
        if let lastSuccessfulScanDate,
           now().timeIntervalSince(lastSuccessfulScanDate) < cacheDuration,
           !networks.isEmpty {
            return
        }
        await scan(force: false)
    }

    func refresh() async {
        refreshIsPending = false
        await scan(force: true)
    }

    func refreshAfterCurrentRequest() {
        guard isBusy else {
            Task { @MainActor in await refresh() }
            return
        }
        refreshIsPending = true
    }

    func scan(force: Bool) async {
        guard !isBusy else { return }
        if !force,
           let lastSuccessfulScanDate,
           now().timeIntervalSince(lastSuccessfulScanDate) < cacheDuration,
           !networks.isEmpty {
            return
        }

        hasRequestedScan = true
        requestGeneration &+= 1
        let generation = requestGeneration
        state = .scanning

        do {
            let result = try await provider.scan()
            guard generation == requestGeneration else { return }
            isWiFiPoweredOn = result.isWiFiPoweredOn
            networks = result.isWiFiPoweredOn
                ? NearbyWiFiListBuilder.makeNetworks(from: result.networks)
                : []
            lastSuccessfulScanDate = now()
            state = .idle
        } catch {
            guard generation == requestGeneration else { return }
            state = .failure(message: Self.userFacingMessage(for: error))
        }
        await performPendingRefreshIfNeeded()
    }

    @discardableResult
    func join(_ network: NearbyWiFiNetwork, password: String?) async -> Bool {
        guard !network.isCurrent else { return true }
        guard network.security.supportsDirectAssociation else { return false }
        guard !isBusy else { return false }

        requestGeneration &+= 1
        let generation = requestGeneration
        state = .joining(networkID: network.id)

        do {
            try await provider.associate(
                networkID: network.id,
                password: network.security.requiresPassword ? password : nil
            )
            guard generation == requestGeneration else { return false }
            state = .success(networkID: network.id)
            return true
        } catch {
            guard generation == requestGeneration else { return false }
            state = .failure(message: localized("Unable to Join"))
            await performPendingRefreshIfNeeded()
            return false
        }
    }

    func invalidatePendingRequests() {
        requestGeneration &+= 1
        if isBusy { state = .idle }
    }

    func clearTransientState() {
        switch state {
        case .success, .failure: state = .idle
        case .idle, .scanning, .joining: break
        }
    }

    private static func userFacingMessage(for error: Error) -> String {
        if let error = error as? NearbyWiFiProviderError {
            switch error {
            case .wifiOff: return localized("Wi-Fi is Off")
            case .interfaceUnavailable: return localized("Wi-Fi unavailable")
            case .networkUnavailable, .associationUnsupported: return localized("Open Wi-Fi Settings")
            case .scanFailed: return localized("Unable to Scan")
            }
        }
        return localized("Unable to Scan")
    }

    private func performPendingRefreshIfNeeded() async {
        guard refreshIsPending else { return }
        refreshIsPending = false
        await scan(force: true)
    }
}

enum NearbyWiFiProviderError: Error, Equatable, Sendable {
    case wifiOff
    case interfaceUnavailable
    case networkUnavailable
    case associationUnsupported
    case scanFailed
}
