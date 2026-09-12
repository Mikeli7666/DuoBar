import Foundation
import IOKit

enum AccessoryBatteryReader {
    // Driver-published properties are optional. Do not use private Bluetooth
    // selectors, infer a reading from a device name, or retain old readings.
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
