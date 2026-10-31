import Foundation
import XCTest
@testable import DuoBar

final class NetworkSpeedTests: XCTestCase {
    func testFirstSampleProducesNoSpeed() {
        var calculator = NetworkSpeedCalculator()
        let speed = calculator.update(interface: "en0", counters: .init(received: 100, sent: 50), at: 0)
        XCTAssertNil(speed)
    }

    func testRatesAreDerivedFromCounterDeltas() {
        var calculator = NetworkSpeedCalculator()
        _ = calculator.update(interface: "en0", counters: .init(received: 1_000, sent: 500), at: 10)
        let speed = calculator.update(interface: "en0", counters: .init(received: 3_000, sent: 1_500), at: 12)
        XCTAssertEqual(speed?.downloadBytesPerSecond, 1_000)
        XCTAssertEqual(speed?.uploadBytesPerSecond, 500)
    }

    func testThirtyTwoBitCounterWrapAroundIsHandled() {
        var calculator = NetworkSpeedCalculator()
        _ = calculator.update(interface: "en0", counters: .init(received: UInt32.max - 499, sent: UInt32.max - 99), at: 0)
        let speed = calculator.update(interface: "en0", counters: .init(received: 500, sent: 100), at: 1)
        XCTAssertEqual(speed?.downloadBytesPerSecond, 1_000)
        XCTAssertEqual(speed?.uploadBytesPerSecond, 200)
    }

    func testInterfaceChangeRestartsMeasurement() {
        var calculator = NetworkSpeedCalculator()
        _ = calculator.update(interface: "en0", counters: .init(received: 1_000, sent: 1_000), at: 0)
        let switched = calculator.update(interface: "en1", counters: .init(received: 9_000_000, sent: 9_000_000), at: 1)
        XCTAssertNil(switched)
        let next = calculator.update(interface: "en1", counters: .init(received: 9_001_000, sent: 9_000_500), at: 2)
        XCTAssertEqual(next?.downloadBytesPerSecond, 1_000)
        XCTAssertEqual(next?.uploadBytesPerSecond, 500)
    }

    func testImplausibleJumpIsDiscarded() {
        var calculator = NetworkSpeedCalculator()
        _ = calculator.update(interface: "en0", counters: .init(received: 0, sent: 0), at: 0)
        let speed = calculator.update(interface: "en0", counters: .init(received: 3_000_000_000, sent: 0), at: 1)
        XCTAssertNil(speed)
    }

    func testMissingCountersResetTheCalculator() {
        var calculator = NetworkSpeedCalculator()
        _ = calculator.update(interface: "en0", counters: .init(received: 0, sent: 0), at: 0)
        XCTAssertNil(calculator.update(interface: "en0", counters: nil, at: 1))
        XCTAssertNil(calculator.update(interface: "en0", counters: .init(received: 5_000, sent: 5_000), at: 2))
    }

    func testNonAdvancingTimeIsIgnored() {
        var calculator = NetworkSpeedCalculator()
        _ = calculator.update(interface: "en0", counters: .init(received: 0, sent: 0), at: 5)
        XCTAssertNil(calculator.update(interface: "en0", counters: .init(received: 1_000, sent: 1_000), at: 5))
    }

    func testCompactFormatting() {
        XCTAssertEqual(NetworkSpeedFormatter.compact(0), "0B")
        XCTAssertEqual(NetworkSpeedFormatter.compact(-5), "0B")
        XCTAssertEqual(NetworkSpeedFormatter.compact(512), "512B")
        XCTAssertEqual(NetworkSpeedFormatter.compact(999), "999B")
        XCTAssertEqual(NetworkSpeedFormatter.compact(1_000), "1.0K")
        XCTAssertEqual(NetworkSpeedFormatter.compact(1_500), "1.5K")
        XCTAssertEqual(NetworkSpeedFormatter.compact(9_960), "10K")
        XCTAssertEqual(NetworkSpeedFormatter.compact(120_000), "120K")
        XCTAssertEqual(NetworkSpeedFormatter.compact(999_999), "1.0M")
        XCTAssertEqual(NetworkSpeedFormatter.compact(2_400_000), "2.4M")
        XCTAssertEqual(NetworkSpeedFormatter.compact(3_000_000_000), "3.0G")
    }
}
