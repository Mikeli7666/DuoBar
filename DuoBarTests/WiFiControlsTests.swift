import XCTest
@testable import DuoBar

final class WiFiControlsTests: XCTestCase {
    @MainActor
    func testScanningDoesNotChangeRadioOrJoinANetwork() async {
        let worker = FakeWiFiWorker()
        let controls = WiFiControls(worker: worker)
        await controls.scan()
        XCTAssertEqual(controls.networks.count, 1)
        XCTAssertTrue(controls.hasScanned)
        XCTAssertFalse(controls.isBusy)
        let mutations = await worker.mutations
        XCTAssertEqual(mutations, 0)
    }

    @MainActor
    func testFailedJoinReportsFailureAndAllowsRetry() async throws {
        let worker = FakeWiFiWorker()
        let controls = WiFiControls(worker: worker)
        await controls.scan()
        let network = try XCTUnwrap(controls.networks.first)
        await worker.failNextJoin()
        let failed = await controls.join(network, password: "test-only")
        XCTAssertFalse(failed)
        XCTAssertNotNil(controls.errorMessage)
        XCTAssertFalse(controls.isBusy)

        let retried = await controls.join(network, password: "test-only")
        XCTAssertTrue(retried)
        XCTAssertNil(controls.errorMessage)
        XCTAssertFalse(controls.isBusy)
    }

    @MainActor
    func testTurningRadioOffClearsPreviouslyScannedNetworks() async {
        let worker = FakeWiFiWorker()
        let controls = WiFiControls(worker: worker)
        await controls.scan()
        await controls.setPower(false)
        XCTAssertTrue(controls.networks.isEmpty)
        XCTAssertFalse(controls.hasScanned)
        XCTAssertFalse(controls.isBusy)
        let mutations = await worker.mutations
        XCTAssertEqual(mutations, 1)
    }
}

private actor FakeWiFiWorker: WiFiControlWorking {
    private(set) var mutations = 0
    private var shouldFailJoin = false

    func failNextJoin() { shouldFailJoin = true }

    func scan() -> [WiFiNetworkOption] {
        [WiFiNetworkOption(id: UUID(), name: "Test Network", security: .personal, rssi: -50)]
    }

    func setPower(_ enabled: Bool) { mutations += 1 }

    func join(_ id: UUID, password: String) throws {
        mutations += 1
        if shouldFailJoin {
            shouldFailJoin = false
            throw NSError(domain: "DuoBarTests", code: 1)
        }
    }
}
