import Foundation
import XCTest
@testable import DuoBar

final class BatteryTimeEstimateTests: XCTestCase {
    private func resolve(
        charging: Bool = false,
        plugged: Bool = false,
        full: Bool = false,
        toFull: Int? = nil,
        toEmpty: Int? = nil
    ) -> BatteryTimeEstimate {
        BatteryTimeEstimate.resolve(
            isCharging: charging,
            isPluggedIn: plugged,
            isFullyCharged: full,
            timeToFull: toFull,
            timeToEmpty: toEmpty
        )
    }

    func testChargingUsesTimeToFull() {
        XCTAssertEqual(resolve(charging: true, plugged: true, toFull: 65), .toFull(minutes: 65))
        XCTAssertEqual(resolve(charging: true, plugged: true, toFull: -1), .calculating)
        XCTAssertEqual(resolve(charging: true, plugged: true, toFull: nil), .unavailable)
    }

    func testOnBatteryUsesTimeToEmpty() {
        XCTAssertEqual(resolve(toEmpty: 192), .toEmpty(minutes: 192))
        XCTAssertEqual(resolve(toEmpty: -1), .calculating)
        XCTAssertEqual(resolve(toEmpty: nil), .unavailable)
    }

    func testFullyChargedAndHoldHaveNoEstimate() {
        XCTAssertEqual(resolve(charging: true, plugged: true, full: true, toFull: 30), .unavailable)
        XCTAssertEqual(resolve(plugged: true, toFull: 30, toEmpty: 30), .unavailable)
    }

    func testDurationFormatting() {
        let us = Locale(identifier: "en_US")
        func normalised(_ text: String) -> String {
            text.components(separatedBy: .whitespaces).joined(separator: " ")
        }
        XCTAssertEqual(normalised(BatteryTimeFormatter.duration(minutes: 45, locale: us)), "45m")
        XCTAssertEqual(normalised(BatteryTimeFormatter.duration(minutes: 120, locale: us)), "2h")
        XCTAssertEqual(normalised(BatteryTimeFormatter.duration(minutes: 65, locale: us)), "1h 5m")
    }

    private func row(
        charging: Bool = false,
        plugged: Bool = false,
        full: Bool = false,
        lowPower: Bool = false,
        available: Bool = true,
        estimate: BatteryTimeEstimate = .unavailable
    ) -> BatteryStatusRow {
        BatteryStatusRow(
            battery: BatteryStatus(
                percentage: 80,
                isCharging: charging,
                isPluggedIn: plugged,
                isFullyCharged: full,
                isAvailable: available,
                isLowPowerModeEnabled: lowPower
            ),
            showPercentage: true,
            timeEstimate: estimate
        )
    }

    func testChargingRowShowsTimeToFull() {
        let r = row(charging: true, plugged: true, estimate: .toFull(minutes: 65))
        XCTAssertEqual(r.detail, localized("Charging"))
        XCTAssertEqual(r.secondaryDetail, localized("%@ to full", BatteryTimeFormatter.duration(minutes: 65)))
    }

    func testPluggedInButNotChargingIsOnHoldUsingAdapter() {
        let r = row(plugged: true)
        XCTAssertEqual(r.detail, localized("Charging On Hold"))
        XCTAssertEqual(r.secondaryDetail, localized("Using Adapter"))
    }

    func testFullyChargedShowsUsingAdapter() {
        let r = row(plugged: true, full: true)
        XCTAssertEqual(r.detail, localized("Fully charged"))
        XCTAssertEqual(r.secondaryDetail, localized("Using Adapter"))
    }

    func testOnBatteryShowsTimeLeftOrCalculating() {
        let left = row(estimate: .toEmpty(minutes: 192))
        XCTAssertEqual(left.detail, localized("Using battery power"))
        XCTAssertEqual(left.secondaryDetail, localized("%@ left", BatteryTimeFormatter.duration(minutes: 192)))

        let calculating = row(estimate: .calculating)
        XCTAssertEqual(calculating.secondaryDetail, localized("Calculating…"))

        let none = row()
        XCTAssertNil(none.secondaryDetail)
    }

    func testLowPowerModeOnBattery() {
        XCTAssertEqual(row(lowPower: true).detail, localized("Low Power Mode"))
    }

    func testUnavailableBatteryHasNoSecondaryDetail() {
        XCTAssertNil(row(available: false, estimate: .toEmpty(minutes: 10)).secondaryDetail)
    }
}
