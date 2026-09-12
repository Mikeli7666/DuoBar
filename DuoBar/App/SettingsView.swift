import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @AppStorage(PreferenceKeys.showBatteryPercentage) private var showBatteryPercentage = true
    @AppStorage(PreferenceKeys.animationsEnabled) private var animationsEnabled = true
    @AppStorage(PreferenceKeys.showMenuBarBatteryPercentage) private var showMenuBarBatteryPercentage = false
    @StateObject private var launchAtLogin = LaunchAtLoginService()
    @StateObject private var bluetoothMonitor = BluetoothSettingsMonitor()

    var body: some View {
        Form {
            Section("Menu Bar") {
                Toggle("Show battery percentage in menu bar", isOn: $showMenuBarBatteryPercentage)
                Toggle("Show battery percentage in popover", isOn: $showBatteryPercentage)
                Toggle("Enable animations", isOn: $animationsEnabled)
            }

            Section("Bluetooth Dots") {
                BluetoothDotSettingsView(bluetooth: bluetoothMonitor.status)
            }

            Section("General") {
                Toggle(
                    "Launch DuoBar at login",
                    isOn: Binding(
                        get: { launchAtLogin.isEnabled },
                        set: launchAtLogin.setEnabled
                    )
                )

                if launchAtLogin.requiresApproval {
                    Text("Approval is required in System Settings → General → Login Items.")
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
            bluetoothMonitor.start()
        }
        .onDisappear { bluetoothMonitor.stop() }
    }

    private var settingsHeight: CGFloat {
        #if DEBUG
        540
        #else
        480
        #endif
    }
}
