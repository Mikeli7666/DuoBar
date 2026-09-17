import Foundation
import IOKit
import IOBluetooth

enum AccessoryBatteryReader {
    // Match readings only by address, never by display name. Each refresh replaces
    // the previous snapshot; disconnected records are never used for batteries.
    struct DeviceReport: Equatable, Sendable {
        var name: String
        var batteryPercentage: Int?
    }

    static func connectedDeviceReports() -> [String: DeviceReport] {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        process.arguments = ["SPBluetoothDataType", "-json", "-timeout", "8"]
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return [:] }
        // Also bound the process lifetime if a system reporter stalls.
        let timeout = DispatchWorkItem { if process.isRunning { process.terminate() } }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 12, execute: timeout)
        defer { timeout.cancel() }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return [:] }
        return parseConnectedDeviceReports(data)
    }

    static func parseConnectedDeviceReports(_ data: Data) -> [String: DeviceReport] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let controllers = json["SPBluetoothDataType"] as? [[String: Any]] else { return [:] }
        var result: [String: DeviceReport] = [:]
        for controller in controllers {
            guard let devices = controller["device_connected"] as? [[String: Any]] else { continue }
            for device in devices {
                for (name, rawDetails) in device {
                    guard let details = rawDetails as? [String: Any],
                          let address = normalizedAddress(details["device_address"] as? String) else { continue }
                    // Use the lower earbud reading. A case-only reading must not
                    // masquerade as the headphones' remaining charge.
                    let earbuds = ["device_batteryLevelLeft", "device_batteryLevelRight"]
                        .compactMap { reportPercentage(details[$0]) }
                    let level = earbuds.min() ?? reportPercentage(details["device_batteryLevelMain"])
                    result[address] = DeviceReport(name: name, batteryPercentage: level)
                }
            }
        }
        return result
    }

    private static func reportPercentage(_ value: Any?) -> Int? {
        if let value = value as? String {
            let digits = value.replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard let number = Int(digits), (0...100).contains(number) else { return nil }
            return number
        }
        return percentage(value)
    }
    static func batteryLevels() -> [String: Int] {
        var levels: [String: Int] = [:]
        for className in ["IOHIDDevice", "IOHIDEventService"] {
            var iterator: io_iterator_t = 0
            guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching(className), &iterator) == KERN_SUCCESS else { continue }
            defer { IOObjectRelease(iterator) }
            var entry = IOIteratorNext(iterator)
            while entry != 0 {
                if let percentage = percentage(property(entry, "BatteryPercent")) {
                    let address = property(entry, "DeviceAddress") as? String
                    let transport = property(entry, "Transport") as? String ?? ""
                    let serial = transport.hasPrefix("Bluetooth") ? property(entry, "SerialNumber") as? String : nil
                    if let id = normalizedAddress(address ?? serial) {
                        levels[id] = min(levels[id] ?? percentage, percentage)
                    }
                }
                IOObjectRelease(entry)
                entry = IOIteratorNext(iterator)
            }
        }
        return levels
    }

    // System Information omits the battery for some AirPods Max models.
    // This undocumented getter is optional and must be checked before use.
    static func headphoneBatteryLevel(_ device: IOBluetoothDevice) -> Int? {
        guard device.isConnected(),
              device.responds(to: NSSelectorFromString("batteryPercentSingle")) else { return nil }
        return singleBatteryPercentage(device.value(forKey: "batteryPercentSingle"))
    }

    static func singleBatteryPercentage(_ value: Any?) -> Int? {
        // This getter also returns zero when no single-battery report exists.
        // Keep that ambiguous value unavailable; public sources still accept 0%.
        guard let level = percentage(value), level > 0 else { return nil }
        return level
    }

    static func normalizedAddress(_ address: String?) -> String? {
        guard let address else { return nil }
        let compact = address.lowercased().replacingOccurrences(of: "-", with: "").replacingOccurrences(of: ":", with: "")
        guard compact.count == 12, compact.allSatisfy({ "0123456789abcdef".contains($0) }) else { return nil }
        return compact
    }

    static func percentage(_ value: Any?) -> Int? {
        guard let number = value as? NSNumber,
              CFGetTypeID(number) != CFBooleanGetTypeID(),
              (0...100).contains(number.doubleValue),
              number.doubleValue.rounded() == number.doubleValue else { return nil }
        return number.intValue
    }

    private static func property(_ entry: io_registry_entry_t, _ key: String) -> Any? {
        IORegistryEntryCreateCFProperty(entry, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
    }
}
