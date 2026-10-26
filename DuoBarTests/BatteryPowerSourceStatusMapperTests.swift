import IOKit.ps
import XCTest
@testable import DuoBar

final class BatteryPowerSourceStatusMapperTests: XCTestCase {
    func testDisplayedOneHundredPercentWithoutAuthoritativeFullStaysCharging() {
        let status = makeStatus(percentage: 100, charging: true, plugged: true, charged: false)

        XCTAssertEqual(status.percentage, 100)
        XCTAssertTrue(status.isCharging)
        XCTAssertTrue(status.isPluggedIn)
        XCTAssertFalse(status.isFullyCharged)
    }

    func testDisplayedOneHundredPercentWithoutIsChargedNeverInfersFull() {
        let status = makeStatus(percentage: 100, charging: false, plugged: true, charged: nil)

        XCTAssertEqual(status.percentage, 100)
        XCTAssertTrue(status.isPluggedIn)
        XCTAssertFalse(status.isCharging)
        XCTAssertFalse(status.isFullyCharged)
    }

    func testAuthoritativeFullWinsOverAChargingSnapshot() {
        let status = makeStatus(percentage: 100, charging: true, plugged: true, charged: true)

        XCTAssertTrue(status.isFullyCharged)
        XCTAssertTrue(status.isPluggedIn)
    }

    func testUnpluggedStateCannotBecomeAuthoritativelyFullWithoutIOPowerSourcesFlag() {
        let status = makeStatus(percentage: 100, charging: false, plugged: false, charged: nil)

        XCTAssertFalse(status.isPluggedIn)
        XCTAssertFalse(status.isFullyCharged)
    }

    func testChargingToFullAndFullToUnpluggedSequencesPreserveAuthority() {
        let charging = makeStatus(percentage: 99, charging: true, plugged: true, charged: false)
        let full = makeStatus(percentage: 100, charging: false, plugged: true, charged: true)
        let unplugged = makeStatus(percentage: 100, charging: false, plugged: false, charged: false)

        XCTAssertFalse(charging.isFullyCharged)
        XCTAssertTrue(full.isFullyCharged)
        XCTAssertFalse(unplugged.isFullyCharged)
        XCTAssertFalse(unplugged.isPluggedIn)
    }

    func testMissingCapacityDoesNotFabricatePercentageOrFullState() {
        let status = BatteryPowerSourceStatusMapper.status(
            currentCapacity: nil,
            maximumCapacity: nil,
            isCharging: false,
            powerSourceState: kIOPSACPowerValue,
            isCharged: nil,
            lowPowerModeEnabled: false
        )

        XCTAssertNil(status.percentage)
        XCTAssertFalse(status.isFullyCharged)
    }

    private func makeStatus(percentage: Int, charging: Bool, plugged: Bool, charged: Bool?) -> BatteryStatus {
        BatteryPowerSourceStatusMapper.status(
            currentCapacity: percentage,
            maximumCapacity: 100,
            isCharging: charging,
            powerSourceState: plugged ? kIOPSACPowerValue : kIOPSBatteryPowerValue,
            isCharged: charged,
            lowPowerModeEnabled: false
        )
    }
}
