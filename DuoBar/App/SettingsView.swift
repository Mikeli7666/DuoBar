import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @AppStorage(PreferenceKeys.showBatteryPercentage) private var showBatteryPercentage = true
    @AppStorage(PreferenceKeys.animationsEnabled) private var animationsEnabled = true
    @AppStorage(PreferenceKeys.menuBarIconScale) private var menuBarIconScale = MenuBarIconSize.defaultScale
    @AppStorage(PreferenceKeys.batteryColorCoding) private var batteryColorCoding = false
    @AppStorage(PreferenceKeys.adaptiveRingEnabled) private var adaptiveRingEnabled = true
    @AppStorage(PreferenceKeys.adaptiveRingPriority) private var adaptiveRingPriorityRaw = PerformancePreference.automatic.rawValue
    @AppStorage(PreferenceKeys.adaptiveRingColorCoding) private var adaptiveRingColorCoding = false
    @AppStorage(PreferenceKeys.outerRingChoice) private var outerRingChoiceRaw = OuterRingChoice.automatic.rawValue
    @AppStorage(PreferenceKeys.openOnHover) private var openOnHover = false
    @StateObject private var launchAtLogin = LaunchAtLoginService()
    @ObservedObject private var adaptiveRingMonitor = AdaptiveRingMonitor.shared
    private let deviceContextService = DeviceContextService()
    #if DEBUG
    @AppStorage(PreferenceKeys.simulateDesktopMac) private var simulateDesktopMac = false
    #endif

    var body: some View {
        Form {
            Section(localized("Menu Bar")) {
                Toggle(localized("Show battery percentage in popover"), isOn: $showBatteryPercentage)
                Toggle(localized("Enable animations"), isOn: $animationsEnabled)

                VStack(alignment: .leading, spacing: 6) {
                    Text(localized("Icon Size"))
                    Picker(localized("Icon Size"), selection: resolvedMenuBarIconScale) {
                        Text(localized("Small")).tag(MenuBarIconSize.minimumScale)
                        Text(localized("Default")).tag(MenuBarIconSize.defaultScale)
                        Text(localized("Large")).tag(MenuBarIconSize.maximumScale)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel(localized("Menu bar icon size"))
                    HStack(spacing: 10) {
                        Text(localized("Small"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Slider(
                            value: resolvedMenuBarIconScale,
                            in: MenuBarIconSize.minimumScale...MenuBarIconSize.maximumScale,
                            step: MenuBarIconSize.step
                        )
                        .accessibilityLabel(localized("Menu bar icon size"))
                        .accessibilityValue(localized("%d%%", Int((MenuBarIconSize.resolve(menuBarIconScale) * 100).rounded())))
                        Text(localized("Large"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(localized("Choose a preset or fine-tune DuoBar to better match your menu bar."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section(localized("General")) {
                VStack(alignment: .leading, spacing: 4) {
                    Toggle(localized("Open on Hover"), isOn: $openOnHover)
                        .toggleStyle(.switch)
                    Text(localized("Open DuoBar when the pointer moves over the menu bar icon."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Toggle(
                    localized("Launch DuoBar at login"),
                    isOn: Binding(
                        get: { launchAtLogin.isEnabled },
                        set: launchAtLogin.setEnabled
                    )
                )

                if launchAtLogin.requiresApproval {
                    Text(localized("Approval is required in System Settings → General → Login Items."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let errorMessage = launchAtLogin.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }
            }

            Section(localized("Outer Ring")) {
                Picker(localized("Outer Ring"), selection: outerRingChoice) {
                    ForEach(OuterRingChoice.allCases) { choice in
                        Text(localized(choice.localizationKey)).tag(choice)
                    }
                }
                Text(localized("Choose what the outer arc shows. Automatic keeps battery level while on battery power and switches while charging."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if showsBatteryRingSettings {
                Section(localized("Battery Ring")) {
                    Toggle(localized("Battery Color Coding"), isOn: $batteryColorCoding)
                }
            }

            if showsAdaptiveRingSettings {
                Section(localized("Adaptive Ring")) {
                    Toggle(localized("Enable Adaptive Ring"), isOn: $adaptiveRingEnabled)
                    Text(localized("While charging, the outer arc can leave battery level and show brightness, processor, memory, or heat."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if adaptiveRingEnabled {
                        Picker(localized("Adaptive Ring Priority"), selection: adaptiveRingPriority) {
                            ForEach(PerformancePreference.allCases, id: \.self) { preference in
                                Text(preference.localizedDisplayName).tag(preference)
                            }
                        }
                        Text(localized("Used only when multiple system conditions need attention. Critical conditions can still take priority."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Toggle(localized("Adaptive Ring Color Coding"), isOn: $adaptiveRingColorCoding)
                }
            }

            #if DEBUG
            if !MarketingCaptureMode.isEnabled {
                DebugPerformanceDiagnosticsView()
                DebugDuoGlyphTuningView()
            }
            #endif
        }
        .formStyle(.grouped)
        .scenePadding()
        .frame(width: 420, height: settingsHeight)
        .navigationTitle(localized("DuoBar Settings"))
        .onAppear {
            NSApp.activate(ignoringOtherApps: true)
            launchAtLogin.refresh()
            if showsAdaptiveRingSettings {
                adaptiveRingMonitor.setPreference(adaptiveRingPriority.wrappedValue)
            }
        }
        .onChange(of: adaptiveRingPriorityRaw) { _ in
            if showsAdaptiveRingSettings {
                adaptiveRingMonitor.setPreference(adaptiveRingPriority.wrappedValue)
            }
        }
    }

    private var settingsHeight: CGFloat {
        #if DEBUG
        MarketingCaptureMode.isEnabled ? 360 : 850
        #else
        470
        #endif
    }

    private var outerRingChoice: Binding<OuterRingChoice> {
        Binding(
            get: { OuterRingChoice(stored: outerRingChoiceRaw) },
            set: { outerRingChoiceRaw = $0.rawValue }
        )
    }

    private var adaptiveRingPriority: Binding<PerformancePreference> {
        Binding(
            get: { PerformancePreference(rawValue: adaptiveRingPriorityRaw) ?? .automatic },
            set: { adaptiveRingPriorityRaw = $0.rawValue }
        )
    }

    private var resolvedMenuBarIconScale: Binding<Double> {
        Binding(
            get: { MenuBarIconSize.resolve(menuBarIconScale) },
            set: { menuBarIconScale = MenuBarIconSize.resolve($0) }
        )
    }

    private var showsAdaptiveRingSettings: Bool {
        #if DEBUG
        AdaptiveRingSettingsEligibility.isEligible(
            for: deviceContextService.current(),
            simulateDesktop: simulateDesktopMac
        )
        #else
        AdaptiveRingSettingsEligibility.isEligible(for: deviceContextService.current())
        #endif
    }

    private var showsBatteryRingSettings: Bool {
        #if DEBUG
        deviceContextService.current(simulateDesktop: simulateDesktopMac).ringBehavior == .batteryRing
        #else
        deviceContextService.current().ringBehavior == .batteryRing
        #endif
    }
}
