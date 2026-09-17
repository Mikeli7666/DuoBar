enum PreferenceKeys {
    static let glyphStyle = "glyphStyle"
    static let glyphSize = "glyphSize"
    static let percentageOnlyBelow = "percentageOnlyBelow"
    static let percentageThreshold = "percentageThreshold"
    static let showAirplaneIndicator = "showAirplaneIndicator"

    static let showBatteryPercentage = "showBatteryPercentage"
    static let showMenuBarBatteryPercentage = "showMenuBarBatteryPercentage"
    static let animationsEnabled = "animationsEnabled"
    static let bluetoothDotMode = "bluetoothDotMode"
    static let bluetoothDotSlot1 = "bluetoothDotSlot1"
    static let bluetoothDotSlot2 = "bluetoothDotSlot2"
    static let bluetoothDotSlot3 = "bluetoothDotSlot3"
    static let bluetoothDotSlot4 = "bluetoothDotSlot4"
    static let bluetoothDotBatteryDevice = "bluetoothDotBatteryDevice"
}

// Shared by the external percentage and the split-ring label.
enum BatteryPercentageVisibility {
    static func shouldShow(_ battery: BatteryStatus, enabled: Bool, onlyBelow: Bool, threshold: Int) -> Bool {
        guard enabled, battery.isAvailable, let value = battery.percentage,
              (0...100).contains(value) else { return false }
        return !onlyBelow || value < min(max(threshold, 1), 100)
    }
}

enum DuoGlyphStyle: String, CaseIterable, Identifiable {
    case classic, splitRing
    var id: String { rawValue }
    var title: String { self == .classic ? "Classic" : "Split ring" }
}
