import AppKit
import XCTest
@testable import DuoBar

final class SettingsAndBatteryTests: XCTestCase {
    @MainActor
    func testSettingsWindowReopensAndReusesWindow() throws {
        let controller = SettingsWindowController()
        let store = SystemStatusStore(startServices: false)
        controller.show(statusStore: store)
        let first = try XCTUnwrap(controller.window)
        XCTAssertTrue(first.isVisible)
        controller.close()
        XCTAssertFalse(first.isVisible)
        controller.show(statusStore: store)
        XCTAssertTrue(controller.window === first)
        XCTAssertTrue(first.isVisible)
        controller.close()
    }

    func testBatteryColorBoundariesAndPowerStatePrecedence() {
        var battery = BatteryStatus(percentage: 50, isCharging: false, isPluggedIn: false,
                                    isFullyCharged: false, isAvailable: true)
        for (percentage, expected): (Int, BatteryRingState) in [
            (0, .critical), (10, .critical), (11, .low), (20, .low), (21, .normal), (100, .normal)
        ] {
            battery.percentage = percentage
            XCTAssertEqual(battery.ringState, expected)
        }
        battery.percentage = 5
        battery.isPluggedIn = true
        XCTAssertEqual(battery.ringState, .pluggedIn)
        battery.isCharging = true
        XCTAssertEqual(battery.ringState, .charging)
        battery.isCharging = false
        battery.isFullyCharged = true
        XCTAssertEqual(battery.ringState, .full)
        battery.isAvailable = false
        XCTAssertEqual(battery.ringState, .unavailable)
        battery.isAvailable = true
        battery.isFullyCharged = false
        battery.isPluggedIn = false
        battery.percentage = nil
        XCTAssertEqual(battery.ringState, .unavailable)
    }
}
