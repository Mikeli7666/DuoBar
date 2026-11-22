import SwiftUI

/// TEMP — privileged-helper verification panel. REMOVE before 1.4.2 release.
///
/// Release builds only: `installIfNeeded()` refuses DEBUG builds (the
/// Development certificate does not match the helper's SMAuthorizedClients
/// requirement), so this panel is deliberately NOT wrapped in `#if DEBUG`.
/// Delete this file and the `TempHelperTestView()` line in SettingsView
/// once the helper is verified.
struct TempHelperTestView: View {
    @ObservedObject private var client = PrivilegedHelperClient.shared
    @State private var resultText = ""
    @State private var ethernetInterface = "en0"

    /// Diagnostic: which app bundle is actually running, and whether the
    /// daemon plist + helper binary are visible from inside it.
    private var bundleDiagnostics: String {
        let bundlePath = Bundle.main.bundlePath
        let plistPath = (bundlePath as NSString).appendingPathComponent("Contents/Library/LaunchDaemons/com.mikeli.duobar.helper.plist")
        let helperPath = (bundlePath as NSString).appendingPathComponent("Contents/Library/LaunchDaemons/com.mikeli.duobar.helper")
        let plistExists = FileManager.default.fileExists(atPath: plistPath)
        let helperExists = FileManager.default.fileExists(atPath: helperPath)
        return "Bundle: \(bundlePath)\nPlist in bundle: \(plistExists)\nHelper in bundle: \(helperExists)"
    }

    var body: some View {
        Section("Privileged Helper (TEMP)") {
            HStack {
                Text(client.isInstalled ? "Installed" : "Not installed")
                if let error = client.lastError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Button("Install Helper") {
                Task {
                    let ok = await client.installIfNeeded()
                    resultText = ok ? "Install OK — helper answered ping" : (client.lastError ?? "Install failed")
                }
            }

            Button("Read Charge Limit (record the original value first)") {
                Task {
                    if let limit = await client.readChargeLimit() {
                        resultText = "Charge limit: \(limit)%"
                    } else {
                        resultText = client.lastError ?? "Read charge limit failed"
                    }
                }
            }
            HStack {
                Button("Set Charge Limit 80") {
                    Task {
                        let ok = await client.setChargeLimit(80)
                        resultText = ok ? "Charge limit set to 80 (read back OK)" : (client.lastError ?? "Set charge limit failed")
                    }
                }
                Button("Set Charge Limit 100 (restore)") {
                    Task {
                        let ok = await client.setChargeLimit(100)
                        resultText = ok ? "Charge limit restored to 100" : (client.lastError ?? "Set charge limit failed")
                    }
                }
            }

            Button("Read Low Power Mode") {
                Task {
                    if let state = await client.readLowPowerMode() {
                        resultText = "Low Power Mode: \(state ? "ON" : "OFF")"
                    } else {
                        resultText = client.lastError ?? "Read low power mode failed"
                    }
                }
            }
            HStack {
                Button("Low Power ON") {
                    Task {
                        let ok = await client.setLowPowerMode(true)
                        resultText = ok ? "Low Power Mode ON" : (client.lastError ?? "Set low power mode failed")
                    }
                }
                Button("Low Power OFF") {
                    Task {
                        let ok = await client.setLowPowerMode(false)
                        resultText = ok ? "Low Power Mode OFF" : (client.lastError ?? "Set low power mode failed")
                    }
                }
            }

            HStack {
                TextField("Interface", text: $ethernetInterface)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                Button("Read Ethernet") {
                    Task {
                        if let enabled = await client.readEthernetEnabled(ethernetInterface) {
                            resultText = "Ethernet \(ethernetInterface): \(enabled ? "UP" : "DOWN")"
                        } else {
                            resultText = client.lastError ?? "Read ethernet failed"
                        }
                    }
                }
            }
            HStack {
                Button("Ethernet OFF") {
                    Task {
                        let ok = await client.setEthernetEnabled(false, interface: ethernetInterface)
                        resultText = ok ? "Ethernet \(ethernetInterface) OFF" : (client.lastError ?? "Set ethernet failed")
                    }
                }
                Button("Ethernet ON") {
                    Task {
                        let ok = await client.setEthernetEnabled(true, interface: ethernetInterface)
                        resultText = ok ? "Ethernet \(ethernetInterface) ON" : (client.lastError ?? "Set ethernet failed")
                    }
                }
            }

            Button("Uninstall Helper") {
                Task {
                    let ok = await client.uninstall()
                    resultText = ok ? "Helper uninstalled (charge limit reset to 100)" : (client.lastError ?? "Uninstall failed")
                }
            }
            .foregroundStyle(.red)

            if !resultText.isEmpty {
                Text(resultText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(bundleDiagnostics)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }
}
