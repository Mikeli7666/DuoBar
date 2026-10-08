enum PreferenceKeys {
    static let showBatteryPercentage = "showBatteryPercentage"
    static let animationsEnabled = "animationsEnabled"
    static let menuBarIconScale = MenuBarIconSize.preferenceKey
    static let batteryColorCoding = "batteryColorCoding"
    static let adaptiveRingPriority = "adaptiveRingPriority"
    static let adaptiveRingEnabled = "adaptiveRingEnabled"
    static let adaptiveRingColorCoding = "adaptiveRingColorCoding"
    static let outerRingChoice = "outerRingChoice"
    static let openOnHover = "duoBar.openOnHover"

    #if DEBUG
    static let simulateDesktopMac = "debug.simulateDesktopMac"
    #endif
}
