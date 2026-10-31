import Foundation

/// Cumulative byte counters of one network interface. `getifaddrs` exposes
/// 32-bit counters, so they wrap every 4 GiB.
struct InterfaceByteCounters: Equatable, Sendable {
    var received: UInt32
    var sent: UInt32
}

/// Download and upload rates in bytes per second.
struct NetworkSpeed: Equatable, Sendable {
    var downloadBytesPerSecond: Double
    var uploadBytesPerSecond: Double

    static let zero = NetworkSpeed(downloadBytesPerSecond: 0, uploadBytesPerSecond: 0)
}

/// Turns successive cumulative counters into rates.
struct NetworkSpeedCalculator {
    /// Anything faster than this is a counter reset, not real traffic.
    static let maximumPlausibleBytesPerSecond: Double = 2_000_000_000

    private var interfaceName: String?
    private var previous: (counters: InterfaceByteCounters, time: TimeInterval)?

    mutating func reset() {
        interfaceName = nil
        previous = nil
    }

    /// Returns nil for the first sample, after the interface changed, or when
    /// the reading is not trustworthy.
    mutating func update(
        interface: String?,
        counters: InterfaceByteCounters?,
        at time: TimeInterval
    ) -> NetworkSpeed? {
        guard let interface, let counters else {
            reset()
            return nil
        }
        let last = previous
        let sameInterface = interfaceName == interface
        interfaceName = interface
        previous = (counters, time)

        guard sameInterface, let last, time > last.time else { return nil }
        let elapsed = time - last.time
        // Modular subtraction keeps the 32-bit wrap-around correct.
        let received = Double(counters.received &- last.counters.received) / elapsed
        let sent = Double(counters.sent &- last.counters.sent) / elapsed
        guard received <= Self.maximumPlausibleBytesPerSecond,
              sent <= Self.maximumPlausibleBytesPerSecond else { return nil }
        return NetworkSpeed(downloadBytesPerSecond: received, uploadBytesPerSecond: sent)
    }
}

enum NetworkSpeedFormatter {
    private static let units = ["B", "K", "M", "G"]

    /// Compact decimal rate such as "512B", "2.4M" or "120K".
    static func compact(_ bytesPerSecond: Double) -> String {
        var value = max(0, bytesPerSecond)
        var index = 0
        while value >= 999.5, index < units.count - 1 {
            value /= 1000
            index += 1
        }
        if index == 0 {
            return "\(Int(value.rounded()))B"
        }
        if value < 9.95 {
            return String(format: "%.1f%@", value, units[index])
        }
        return String(format: "%.0f%@", value, units[index])
    }
}
