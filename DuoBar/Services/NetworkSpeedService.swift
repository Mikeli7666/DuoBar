import Darwin
import Foundation

/// Samples the byte counters of the active network interface once per second
/// and reports download/upload rates. It only runs while someone is looking
/// (the popover, later the desktop widget), so it costs nothing otherwise.
@MainActor
final class NetworkSpeedService {
    /// nil means "no trustworthy reading yet" (first second, interface change, stopped).
    var onSpeedChange: ((NetworkSpeed?) -> Void)?

    private var timer: Timer?
    private var calculator = NetworkSpeedCalculator()
    private var interfaceName: String?

    var isRunning: Bool { timer != nil }

    func start() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sample() }
        }
        timer.tolerance = 0.1
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
        sample()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        calculator.reset()
        onSpeedChange?(nil)
    }

    func setInterface(_ name: String?) {
        guard name != interfaceName else { return }
        interfaceName = name
        guard isRunning else { return }
        calculator.reset()
        onSpeedChange?(nil)
        sample()
    }

    private func sample() {
        let counters = interfaceName.flatMap(Self.readCounters(for:))
        let speed = calculator.update(
            interface: interfaceName,
            counters: counters,
            at: ProcessInfo.processInfo.systemUptime
        )
        onSpeedChange?(speed)
    }

    nonisolated static func readCounters(for name: String) -> InterfaceByteCounters? {
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else { return nil }
        defer { freeifaddrs(head) }

        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let entry = cursor {
            let item = entry.pointee
            if let address = item.ifa_addr,
               address.pointee.sa_family == UInt8(AF_LINK),
               String(cString: item.ifa_name) == name,
               let data = item.ifa_data {
                let stats = data.assumingMemoryBound(to: if_data.self).pointee
                return InterfaceByteCounters(received: stats.ifi_ibytes, sent: stats.ifi_obytes)
            }
            cursor = item.ifa_next
        }
        return nil
    }
}
