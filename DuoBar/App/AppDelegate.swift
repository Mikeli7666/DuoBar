import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let isRunningTests: Bool
    private var instanceLock: ApplicationInstanceLock?
    private var statusStore: SystemStatusStore?
    private var menuBarController: MenuBarController?
    private var wakeObserver: NSObjectProtocol?
    private var dockPreferenceObserver: NSObjectProtocol?
    private var hasPresentedDiskImageInstallHelp = false

    #if DEBUG
    private var marketingCaptureObserver: NSObjectProtocol?
    private var marketingPopoverObserver: NSObjectProtocol?
    #endif

    override init() {
        isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        UserDefaults.standard.register(defaults: [
            PreferenceKeys.showBatteryPercentage: true,
            PreferenceKeys.animationsEnabled: true,
            PreferenceKeys.menuBarIconScale: MenuBarIconSize.defaultScale,
            PreferenceKeys.batteryColorCoding: false,
            PreferenceKeys.openOnHover: false,
            PreferenceKeys.showInDock: false,
            PreferenceKeys.showBatteryPercentageInMenuBar: false
        ])
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !isRunningTests else { return }
        guard menuBarController == nil else { return }

        let instanceLock = ApplicationInstanceLock()
        guard instanceLock.acquire() else {
            #if DEBUG
            NSLog("[DuoBar] another instance already owns the menu-bar item")
            #endif
            NSApp.terminate(nil)
            return
        }
        self.instanceLock = instanceLock

        applyDockPolicy()
        dockPreferenceObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.applyDockPolicy()
            }
        }
        let statusStore = SystemStatusStore()
        self.statusStore = statusStore

        #if DEBUG
        if MarketingCaptureMode.isEnabled {
            statusStore.applyMarketingCaptureState(MarketingCaptureMode.initialState)
            marketingCaptureObserver = DistributedNotificationCenter.default().addObserver(
                forName: MarketingCaptureMode.stateNotification,
                object: nil,
                queue: .main
            ) { [weak statusStore] notification in
                guard let state = notification.userInfo?["state"] as? String else { return }
                Task { @MainActor in
                    statusStore?.applyMarketingCaptureState(state)
                }
            }
        }
        #endif

        let menuBarController = MenuBarController(statusStore: statusStore)
        self.menuBarController = menuBarController

        presentDiskImageInstallHelpIfNeeded()

        #if DEBUG
        if MarketingCaptureMode.isEnabled, MarketingCaptureMode.opensPopover {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak menuBarController] in
                menuBarController?.setPopoverVisibleForMarketingCapture(true)
            }
        }
        if MarketingCaptureMode.isEnabled {
            marketingPopoverObserver = DistributedNotificationCenter.default().addObserver(
                forName: MarketingCaptureMode.popoverNotification,
                object: nil,
                queue: .main
            ) { [weak menuBarController] notification in
                guard let visible = notification.userInfo?["visible"] as? Bool else { return }
                Task { @MainActor in
                    menuBarController?.setPopoverVisibleForMarketingCapture(visible)
                }
            }
        }
        #endif

        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak statusStore] _ in
            Task { @MainActor in
                statusStore?.refresh()
            }
        }
    }

    private func applyDockPolicy() {
        let wantsDock = UserDefaults.standard.bool(forKey: PreferenceKeys.showInDock)
        let target: NSApplication.ActivationPolicy = wantsDock ? .regular : .accessory
        guard NSApp.activationPolicy() != target else { return }
        NSApp.setActivationPolicy(target)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard UserDefaults.standard.bool(forKey: PreferenceKeys.showInDock) else { return true }
        openSettingsWindow()
        return false
    }

    private func openSettingsWindow() {
        NSApp.activate(ignoringOtherApps: true)
        guard let item = settingsMenuItem(in: NSApp.mainMenu), let action = item.action else { return }
        NSApp.sendAction(action, to: item.target, from: item)
    }

    private func settingsMenuItem(in menu: NSMenu?) -> NSMenuItem? {
        guard let menu else { return nil }
        for item in menu.items {
            if item.keyEquivalent == ",", item.keyEquivalentModifierMask.contains(.command) {
                return item
            }
            if let found = settingsMenuItem(in: item.submenu) {
                return found
            }
        }
        return nil
    }

    private func presentDiskImageInstallHelpIfNeeded() {
        guard InstallationLocation.shouldOfferApplicationsHelp(
            bundleURL: Bundle.main.bundleURL,
            hasPresentedThisLaunch: hasPresentedDiskImageInstallHelp
        ) else { return }

        hasPresentedDiskImageInstallHelp = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            let alert = NSAlert()
            alert.messageText = localized("DuoBar is running from the disk image.")
            alert.informativeText = localized("Move DuoBar to Applications to keep it installed after ejecting the disk image.")
            alert.addButton(withTitle: localized("Open Applications"))
            alert.addButton(withTitle: localized("Not Now"))

            if alert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications", isDirectory: true))
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        #if DEBUG
        if let marketingCaptureObserver {
            DistributedNotificationCenter.default().removeObserver(marketingCaptureObserver)
            self.marketingCaptureObserver = nil
        }
        if let marketingPopoverObserver {
            DistributedNotificationCenter.default().removeObserver(marketingPopoverObserver)
            self.marketingPopoverObserver = nil
        }
        #endif

        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
            self.wakeObserver = nil
        }
        if let dockPreferenceObserver {
            NotificationCenter.default.removeObserver(dockPreferenceObserver)
            self.dockPreferenceObserver = nil
        }
        menuBarController?.invalidate()
        menuBarController = nil
        statusStore = nil
        instanceLock?.release()
        instanceLock = nil
    }
}
