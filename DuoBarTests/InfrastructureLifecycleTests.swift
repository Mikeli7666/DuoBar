import XCTest
import ServiceManagement
@testable import DuoBar

final class InfrastructureLifecycleTests: XCTestCase {
    @MainActor
    func testLoginApprovalIsNotEnabledAndOpensSettings() {
        var opened = false
        var registered = false
        let service = LaunchAtLoginService(status: { .requiresApproval },
            register: { registered = true }, unregister: {}, openLoginSettings: { opened = true })
        XCTAssertFalse(service.isEnabled)
        XCTAssertTrue(service.requiresApproval)
        service.setEnabled(true)
        XCTAssertTrue(opened)
        XCTAssertFalse(registered)
    }

    @MainActor
    func testLoginRepairReplacesRegistrationAndRefreshesStatus() {
        var status = SMAppService.Status.enabled
        var operations: [String] = []
        let service = LaunchAtLoginService(status: { status }, register: {
            operations.append("register")
            status = .requiresApproval
        }, unregister: {
            operations.append("unregister")
            status = .notRegistered
        })
        service.repairRegistration()
        XCTAssertEqual(operations, ["unregister", "register"])
        XCTAssertFalse(service.isEnabled)
        XCTAssertTrue(service.requiresApproval)
    }

    @MainActor
    func testLoginRegistrationFailureIsReported() {
        let service = LaunchAtLoginService(status: { .notRegistered }, register: {
            throw NSError(domain: "LoginTest", code: 1)
        }, unregister: {})
        service.setEnabled(true)
        XCTAssertFalse(service.isEnabled)
        XCTAssertNotNil(service.errorMessage)
    }

    @MainActor
    func testBatteryServicePublishesAnInitialReading() {
        let service = BatteryService()
        var readings: [BatteryStatus] = []
        service.onStatusChange = { readings.append($0) }

        service.start()

        XCTAssertEqual(readings.count, 1)
    }

    func testOnlyOneInstanceLockCanOwnAName() {
        let lockName = "com.mikeli.duobar.tests.\(UUID().uuidString).lock"
        let first = ApplicationInstanceLock(lockFileName: lockName)
        let second = ApplicationInstanceLock(lockFileName: lockName)

        XCTAssertTrue(first.acquire())
        XCTAssertFalse(second.acquire())

        first.release()
        XCTAssertTrue(second.acquire())
    }
}
