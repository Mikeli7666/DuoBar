enum PreferenceKeys {
    static let showBatteryPercentage = "showBatteryPercentage"
    static let animationsEnabled = "animationsEnabled"
    static let menuBarIconScale = MenuBarIconSize.preferenceKey
    static let batteryColorCoding = "batteryColorCoding"
    static let adaptiveRingPriority = "adaptiveRingPriority"
    static let adaptiveRingColorCoding = "adaptiveRingColorCoding"
    static let openOnHover = "duoBar.openOnHover"
    static let showInDock = "duoBar.showInDock"
    static let showBatteryPercentageInMenuBar = "showBatteryPercentageInMenuBar"
    static let appLanguage = "duoBar.appLanguage"
    static let showDesktopWidget = "duoBar.showDesktopWidget"
    static let desktopWidgetMode = "duoBar.desktopWidget.mode"
    static let desktopWidgetCustomDots = "duoBar.desktopWidget.customDots"
    static let desktopWidgetCustomCenter = "duoBar.desktopWidget.customCenter"
    static let desktopWidgetCustomRing = "duoBar.desktopWidget.customRing"
    static let desktopWidgetSize = "duoBar.desktopWidget.size"
    static let desktopWidgetFrameX = "duoBar.desktopWidget.frameX"
    static let desktopWidgetFrameY = "duoBar.desktopWidget.frameY"

    #if DEBUG
    static let simulateDesktopMac = "debug.simulateDesktopMac"
    #endif
}
