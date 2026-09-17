import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @AppStorage(PreferenceKeys.showBatteryPercentage) private var showBatteryPercentage = true
    @AppStorage(PreferenceKeys.animationsEnabled) private var animationsEnabled = true
    @AppStorage(PreferenceKeys.showMenuBarBatteryPercentage) private var showMenuBarBatteryPercentage = false
    @AppStorage(PreferenceKeys.glyphStyle) private var glyphStyle: DuoGlyphStyle = .classic
    @AppStorage(PreferenceKeys.glyphSize) private var glyphSize = Double(DuoGlyphMetrics.standard.overallSize)
    @AppStorage(PreferenceKeys.percentageOnlyBelow) private var percentageOnlyBelow = false
    @AppStorage(PreferenceKeys.percentageThreshold) private var percentageThreshold = 20
    @AppStorage(PreferenceKeys.showAirplaneIndicator) private var showAirplaneIndicator = true
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var launchAtLogin = LaunchAtLoginService()
    @ObservedObject var statusStore: SystemStatusStore

    var body: some View {
        Form {
            Section("Menu Bar") {
                Picker("Icon style", selection: $glyphStyle) {
                    ForEach(DuoGlyphStyle.allCases) { Text($0.title).tag($0) }
                }
                HStack {
                    Text("Icon size")
                    Slider(value: $glyphSize, in: 22...30, step: 0.5)
                    Text(glyphSize.formatted(.number.precision(.fractionLength(1))))
                        .monospacedDigit().frame(width: 34)
                }
                Toggle("Airplane icon when both radios are off", isOn: $showAirplaneIndicator)
                Toggle("Show battery percentage in menu bar", isOn: $showMenuBarBatteryPercentage)
                Toggle("Only show menu bar percentage below a threshold", isOn: $percentageOnlyBelow)
                if percentageOnlyBelow {
                    Stepper("Show below \(percentageThreshold)%", value: $percentageThreshold, in: 1...100)
                }
                Text("Split ring places the percentage above the Wi-Fi icon. The airplane icon appears when both Wi-Fi and Bluetooth are off.")
                    .font(.caption).foregroundStyle(.secondary)
                Toggle("Show battery percentage in popover", isOn: $showBatteryPercentage)
                Toggle("Enable animations", isOn: $animationsEnabled)
            }

            Section("Bluetooth Dots") {
                BluetoothDotSettingsView(bluetooth: statusStore.status.bluetooth)
            }

            Section("General") {
                Toggle(
                    "Launch DuoBar at login",
                    isOn: Binding(
                        get: { launchAtLogin.isEnabled },
                        set: launchAtLogin.setEnabled
                    )
                )

                if launchAtLogin.isEnabled {
                    Button("Repair Login Registration") { launchAtLogin.repairRegistration() }
                    Text("If DuoBar does not open at login, repair its registration from the copy in Applications.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if launchAtLogin.requiresApproval {
                    Button("Open Login Items Settings") { SMAppService.openSystemSettingsLoginItems() }
                    Text("DuoBar will not launch at login until you approve it in System Settings → General → Login Items.")
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

            #if DEBUG
            DebugDuoGlyphTuningView()
            #endif
        }
        .formStyle(.grouped)
        .scenePadding()
        .frame(width: 420, height: settingsHeight)
        .navigationTitle("DuoBar Settings")
        .onAppear {
            NSApp.activate(ignoringOtherApps: true)
            launchAtLogin.refresh()
            statusStore.refreshBluetooth()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { launchAtLogin.refresh() }
        }
        .onChange(of: glyphStyle) { _, style in
            if style == .splitRing { showMenuBarBatteryPercentage = true }
        }
    }

    private var settingsHeight: CGFloat {
        #if DEBUG
        680
        #else
        620
        #endif
    }
}
