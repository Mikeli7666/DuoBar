import XCTest
@testable import DuoBar

final class NearbyWiFiTests: XCTestCase {
    func testDeduplicatesSameVisibleIdentityAndKeepsStrongestCandidate() {
        let networks = NearbyWiFiListBuilder.makeNetworks(from: [
            candidate(id: "weak", ssid: "Home", rssi: -79, security: .personal),
            candidate(id: "strong", ssid: "Home", rssi: -48, security: .personal),
            candidate(id: "open", ssid: "Home", rssi: -60, security: .open)
        ])

        XCTAssertEqual(networks.map(\.id), ["strong", "open"])
    }

    func testCurrentNetworkIsFirstEvenWhenAnotherNetworkIsStronger() {
        let networks = NearbyWiFiListBuilder.makeNetworks(from: [
            candidate(id: "strong", ssid: "Cafe", rssi: -35, security: .open),
            candidate(id: "current", ssid: "Home", rssi: -74, security: .personal, isCurrent: true)
        ])

        XCTAssertEqual(networks.map(\.id), ["current", "strong"])
    }

    func testSortingIsSignalFirstThenDeterministicByName() {
        let networks = NearbyWiFiListBuilder.makeNetworks(from: [
            candidate(id: "z", ssid: "Zulu", rssi: -60),
            candidate(id: "a", ssid: "Alpha", rssi: -60),
            candidate(id: "m", ssid: "Medium", rssi: -70)
        ])

        XCTAssertEqual(networks.map(\.id), ["a", "z", "m"])
    }

    func testBlankSSIDValuesAreExcluded() {
        let networks = NearbyWiFiListBuilder.makeNetworks(from: [
            candidate(id: "blank", ssid: "  \n", rssi: -40),
            candidate(id: "valid", ssid: " Home ", rssi: -50)
        ])

        XCTAssertEqual(networks.map(\.ssid), ["Home"])
    }

    func testSignalThresholdsMatchProductionNetworkStatus() {
        XCTAssertEqual(network(id: "strong", rssi: -67).signalLevel, .strong)
        XCTAssertEqual(network(id: "medium-high", rssi: -68).signalLevel, .medium)
        XCTAssertEqual(network(id: "medium-low", rssi: -75).signalLevel, .medium)
        XCTAssertEqual(network(id: "weak", rssi: -76).signalLevel, .weak)
    }

    @MainActor
    func testWiFiOffClearsResultsWithoutReportingScanFailure() async {
        let provider = TestNearbyWiFiProvider(
            scanResult: NearbyWiFiScanResult(isWiFiPoweredOn: false, networks: [])
        )
        let controller = NearbyWiFiController(provider: provider)

        await controller.refresh()

        XCTAssertEqual(controller.isWiFiPoweredOn, false)
        XCTAssertEqual(controller.networks, [])
        XCTAssertEqual(controller.state, .idle)
    }

    @MainActor
    func testControllerDoesNotScanUntilExplicitlyRequested() async {
        let provider = TestNearbyWiFiProvider()
        _ = NearbyWiFiController(provider: provider)

        let scanCallCount = await provider.scanCallCount
        XCTAssertEqual(scanCallCount, 0)
    }

    @MainActor
    func testScanFailureUsesConciseState() async {
        let provider = TestNearbyWiFiProvider(scanError: TestError.failed)
        let controller = NearbyWiFiController(provider: provider)

        await controller.refresh()

        XCTAssertEqual(controller.state, .failure(message: localized("Unable to Scan")))
    }

    @MainActor
    func testFreshNonemptyCachePreventsRepeatedAutomaticScan() async {
        var now = Date(timeIntervalSince1970: 100)
        let provider = TestNearbyWiFiProvider(
            scanResult: NearbyWiFiScanResult(
                isWiFiPoweredOn: true,
                networks: [candidate(id: "home", ssid: "Home", rssi: -50)]
            )
        )
        let controller = NearbyWiFiController(provider: provider, cacheDuration: 15, now: { now })

        await controller.scanIfNeeded()
        now.addTimeInterval(5)
        await controller.scanIfNeeded()

        let scanCallCount = await provider.scanCallCount
        XCTAssertEqual(scanCallCount, 1)
    }

    @MainActor
    func testOverlappingScanIsPrevented() async {
        let provider = TestNearbyWiFiProvider(suspendScan: true)
        let controller = NearbyWiFiController(provider: provider)
        let first = Task { await controller.refresh() }
        await provider.waitUntilScanStarted()

        await controller.refresh()
        let scanCallCount = await provider.scanCallCount
        XCTAssertEqual(scanCallCount, 1)

        await provider.resumeScan()
        await first.value
    }

    @MainActor
    func testStaleScanCompletionIsRejected() async {
        let provider = TestNearbyWiFiProvider(
            scanResult: NearbyWiFiScanResult(
                isWiFiPoweredOn: true,
                networks: [candidate(id: "late", ssid: "Late", rssi: -40)]
            ),
            suspendScan: true
        )
        let controller = NearbyWiFiController(provider: provider)
        let request = Task { await controller.refresh() }
        await provider.waitUntilScanStarted()

        controller.invalidatePendingRequests()
        await provider.resumeScan()
        await request.value

        XCTAssertEqual(controller.networks, [])
        XCTAssertEqual(controller.state, .idle)
    }

    @MainActor
    func testAuthorizationRefreshIsCoalescedUntilCurrentScanFinishes() async {
        let provider = TestNearbyWiFiProvider(suspendScan: true)
        let controller = NearbyWiFiController(provider: provider)
        let first = Task { await controller.refresh() }
        await provider.waitUntilScanStarted()

        controller.refreshAfterCurrentRequest()
        controller.refreshAfterCurrentRequest()
        await provider.resumeScan()
        await first.value

        let scanCallCount = await provider.scanCallCount
        XCTAssertEqual(scanCallCount, 2)
    }

    @MainActor
    func testJoinCannotStartWhileScanIsActive() async {
        let provider = TestNearbyWiFiProvider(suspendScan: true)
        let controller = NearbyWiFiController(provider: provider)
        let scan = Task { await controller.refresh() }
        await provider.waitUntilScanStarted()

        let joined = await controller.join(network(id: "open"), password: nil)
        let associationCallCount = await provider.associationCallCount
        XCTAssertFalse(joined)
        XCTAssertEqual(associationCallCount, 0)

        await provider.resumeScan()
        await scan.value
    }

    @MainActor
    func testSuccessfulJoinAndDuplicateJoinPrevention() async {
        let provider = TestNearbyWiFiProvider(suspendAssociation: true)
        let controller = NearbyWiFiController(provider: provider)
        let selected = network(id: "home", security: .personal)
        let first = Task { await controller.join(selected, password: "secret") }
        await provider.waitUntilAssociationStarted()

        let duplicate = await controller.join(selected, password: "secret")
        XCTAssertFalse(duplicate)
        let associationCallCount = await provider.associationCallCount
        XCTAssertEqual(associationCallCount, 1)

        await provider.resumeAssociation()
        let joined = await first.value
        XCTAssertTrue(joined)
        XCTAssertEqual(controller.state, .success(networkID: "home"))
        let password = await provider.lastPassword
        XCTAssertEqual(password, "secret")
    }

    @MainActor
    func testFailedJoinUsesConciseState() async {
        let provider = TestNearbyWiFiProvider(associationError: TestError.failed)
        let controller = NearbyWiFiController(provider: provider)

        let joined = await controller.join(network(id: "home", security: .personal), password: "wrong")

        XCTAssertFalse(joined)
        XCTAssertEqual(controller.state, .failure(message: localized("Unable to Join")))
    }

    @MainActor
    func testStaleJoinCompletionCannotClaimSuccess() async {
        let provider = TestNearbyWiFiProvider(suspendAssociation: true)
        let controller = NearbyWiFiController(provider: provider)
        let request = Task { await controller.join(network(id: "home"), password: nil) }
        await provider.waitUntilAssociationStarted()

        controller.invalidatePendingRequests()
        await provider.resumeAssociation()

        let joined = await request.value
        XCTAssertFalse(joined)
        XCTAssertEqual(controller.state, .idle)
    }

    @MainActor
    func testCurrentNetworkSelectionDoesNothing() async {
        let provider = TestNearbyWiFiProvider()
        let controller = NearbyWiFiController(provider: provider)

        let result = await controller.join(network(id: "current", isCurrent: true), password: nil)

        XCTAssertTrue(result)
        let associationCallCount = await provider.associationCallCount
        XCTAssertEqual(associationCallCount, 0)
    }

    @MainActor
    func testUnsupportedAssociationFallsBackWithoutCallingProvider() async {
        let provider = TestNearbyWiFiProvider()
        let controller = NearbyWiFiController(provider: provider)

        let result = await controller.join(network(id: "enterprise", security: .enterprise), password: nil)

        XCTAssertFalse(result)
        let associationCallCount = await provider.associationCallCount
        XCTAssertEqual(associationCallCount, 0)
    }

    @MainActor
    func testOpenNetworkNeverSuppliesPassword() async {
        let provider = TestNearbyWiFiProvider()
        let controller = NearbyWiFiController(provider: provider)

        let joined = await controller.join(network(id: "open", security: .open), password: "must-not-pass")
        let password = await provider.lastPassword
        XCTAssertTrue(joined)
        XCTAssertNil(password)
    }

    @MainActor
    func testPasswordNeverAppearsInControllerStateOrNetworkModel() async {
        let provider = TestNearbyWiFiProvider()
        let controller = NearbyWiFiController(provider: provider)
        let secret = "do-not-persist-this"

        _ = await controller.join(network(id: "secured", security: .personal), password: secret)

        XCTAssertFalse(String(describing: controller.state).contains(secret))
        XCTAssertFalse(String(describing: controller.networks).contains(secret))
    }

    private func candidate(
        id: String,
        ssid: String,
        rssi: Int,
        security: NearbyWiFiSecurity = .personal,
        isCurrent: Bool = false
    ) -> NearbyWiFiScanCandidate {
        NearbyWiFiScanCandidate(
            id: id,
            ssid: ssid,
            bssid: nil,
            rssi: rssi,
            channelNumber: nil,
            security: security,
            isCurrent: isCurrent
        )
    }

    private func network(
        id: String,
        rssi: Int = -50,
        security: NearbyWiFiSecurity = .open,
        isCurrent: Bool = false
    ) -> NearbyWiFiNetwork {
        NearbyWiFiNetwork(
            id: id,
            ssid: id,
            rssi: rssi,
            security: security,
            isCurrent: isCurrent
        )
    }
}

private enum TestError: Error {
    case failed
}

private actor TestNearbyWiFiProvider: NearbyWiFiProviding {
    private(set) var scanCallCount = 0
    private(set) var associationCallCount = 0
    private(set) var lastPassword: String?

    private let scanResult: NearbyWiFiScanResult
    private let scanError: Error?
    private let associationError: Error?
    private let suspendScan: Bool
    private let suspendAssociation: Bool
    private var scanStarted = false
    private var associationStarted = false
    private var scanContinuation: CheckedContinuation<Void, Never>?
    private var associationContinuation: CheckedContinuation<Void, Never>?

    init(
        scanResult: NearbyWiFiScanResult = NearbyWiFiScanResult(isWiFiPoweredOn: true, networks: []),
        scanError: Error? = nil,
        associationError: Error? = nil,
        suspendScan: Bool = false,
        suspendAssociation: Bool = false
    ) {
        self.scanResult = scanResult
        self.scanError = scanError
        self.associationError = associationError
        self.suspendScan = suspendScan
        self.suspendAssociation = suspendAssociation
    }

    func scan() async throws -> NearbyWiFiScanResult {
        scanCallCount += 1
        scanStarted = true
        if suspendScan && scanCallCount == 1 {
            await withCheckedContinuation { scanContinuation = $0 }
        }
        if let scanError { throw scanError }
        return scanResult
    }

    func associate(networkID: String, password: String?) async throws {
        associationCallCount += 1
        lastPassword = password
        associationStarted = true
        if suspendAssociation {
            await withCheckedContinuation { associationContinuation = $0 }
        }
        if let associationError { throw associationError }
    }

    func waitUntilScanStarted() async {
        while !scanStarted { await Task.yield() }
    }

    func waitUntilAssociationStarted() async {
        while !associationStarted { await Task.yield() }
    }

    func resumeScan() {
        scanContinuation?.resume()
        scanContinuation = nil
    }

    func resumeAssociation() {
        associationContinuation?.resume()
        associationContinuation = nil
    }
}
