import AppKit
import SwiftUI

struct StatusPopoverView: View {
    @ObservedObject private var statusStore: SystemStatusStore
    @AppStorage(PreferenceKeys.showBatteryPercentage) private var showBatteryPercentage = true
    @AppStorage(PreferenceKeys.batteryColorCoding) private var batteryColorCoding = false
    private let onClose: () -> Void

    init(statusStore: SystemStatusStore, onClose: @escaping () -> Void) {
        self.statusStore = statusStore
        self.onClose = onClose
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("DuoBar")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                Spacer()
                DuoGlyphView(
                    status: statusStore.status,
                    metrics: DuoGlyphMetrics.standard.sized(20),
                    animationsEnabled: false,
                    batteryColorCodingEnabled: batteryColorCoding
                )
            }
            .padding(.horizontal, 2)

            StatusRow(
                symbol: networkSymbol,
                title: localized("Network"),
                detail: networkDetail,
                stateText: networkState,
                tint: .primary,
                trailing: wifiPowerToggle
            )

            VolumeStatusRow(
                volume: statusStore.status.audio.volume,
                hasOutputDevice: statusStore.status.audio.defaultOutput != nil,
                playbackDeviceIdentifier: statusStore.status.audio.defaultOutput?.uid,
                onSetVolume: statusStore.setVolume,
                onSetMuted: statusStore.setMuted
            )

            BatteryStatusRow(
                battery: statusStore.status.battery,
                showPercentage: showBatteryPercentage
            )

            StatusRow(
                symbol: audioOutputSymbol,
                title: localized("Audio Output"),
                detail: audioOutputDetail,
                stateText: audioOutputState,
                tint: .primary
            )

            // Development diagnostics belong in the dedicated DEBUG diagnostics
            // surface, never in the production status-card hierarchy.
            Divider()

            HStack(spacing: 6) {
                settingsAction

                Spacer()

                Button(localized("Quit DuoBar")) {
                    NSApp.terminate(nil)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .font(.system(size: 11.5, weight: .medium))
            .padding(.horizontal, 3)
        }
        .padding(12)
        .frame(width: 304)
        .onAppear {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    @ViewBuilder
    private var settingsAction: some View {
        if #available(macOS 14.0, *) {
            SettingsLink {
                settingsLabel
            }
            .buttonStyle(.plain)
            .simultaneousGesture(TapGesture().onEnded {
                NSApp.activate(ignoringOtherApps: true)
                onClose()
            })
        } else {
            Button(action: openSettingsFromApplicationMenu) {
                settingsLabel
            }
            .buttonStyle(.plain)
        }
    }

    private var settingsLabel: some View {
        Label(localized("Settings"), systemImage: "gearshape")
    }

    private func openSettingsFromApplicationMenu() {
        NSApp.activate(ignoringOtherApps: true)
        if let settingsItem = findSettingsMenuItem(in: NSApp.mainMenu), let action = settingsItem.action {
            NSApp.sendAction(action, to: settingsItem.target, from: settingsItem)
        }
        onClose()
    }

    private func findSettingsMenuItem(in menu: NSMenu?) -> NSMenuItem? {
        guard let menu else { return nil }
        for item in menu.items {
            if item.keyEquivalent == ",", item.keyEquivalentModifierMask.contains(.command) {
                return item
            }
            if let settingsItem = findSettingsMenuItem(in: item.submenu) {
                return settingsItem
            }
        }
        return nil
    }

    private var networkSymbol: String {
        let network = statusStore.status.network
        guard network.isConnected else { return "network.slash" }
        switch network.transport {
        case .wifi: return "wifi"
        case .ethernet: return "cable.connector.horizontal"
        case .other: return "ellipsis.circle"
        case .none: return "network.slash"
        }
    }

    private var networkDetail: String {
        let network = statusStore.status.network
        if statusStore.wifiPowerControlError != nil {
            return localized("Unable to change Wi-Fi power")
        }
        guard network.isAvailable else { return localized("No network interface") }
        guard network.isConnected else {
            return network.isWiFiPoweredOn == false ? localized("Wi-Fi disabled") : localized("Not connected")
        }
        switch network.transport {
        case .wifi: return network.ssid ?? localized("Network name unavailable")
        case .ethernet: return network.interfaceName ?? localized("Wired connection")
        case .other: return network.interfaceName ?? localized("Active connection")
        case .none: return localized("Not connected")
        }
    }

    private var networkState: String {
        let network = statusStore.status.network
        guard network.isAvailable else { return localized("Unavailable") }
        if network.isWiFiPoweredOn == false, !network.isConnected { return localized("Off") }
        guard network.isConnected else { return localized("Offline") }
        switch network.transport {
        case .wifi: return localized("Wi-Fi")
        case .ethernet: return localized("Ethernet")
        case .other: return localized("Connected")
        case .none: return localized("Offline")
        }
    }

    private var wifiPowerToggle: AnyView? {
        guard let wifiPowerState = statusStore.status.network.isWiFiPoweredOn else { return nil }
        return AnyView(
            Toggle(localized("Wi-Fi power"), isOn: Binding(
                get: { wifiPowerState },
                set: { statusStore.setWiFiPower($0) }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.mini)
            .accessibilityLabel(localized("Wi-Fi power"))
        )
    }

    private var audioOutputSymbol: String {
        guard let output = statusStore.status.audio.defaultOutput else { return "speaker.slash" }
        if output.transport.isBluetooth {
            return output.temporaryGlyph == .airPods ? "airpodspro" : "headphones"
        }
        return "speaker.wave.2"
    }

    private var audioOutputDetail: String {
        statusStore.status.audio.defaultOutput?.name ?? localized("No output device")
    }

    private var audioOutputState: String {
        guard let output = statusStore.status.audio.defaultOutput else { return localized("Unavailable") }
        if output.transport.isBluetooth {
            return output.temporaryGlyph == .airPods ? localized("AirPods") : localized("Bluetooth")
        }
        switch output.transport {
        case .builtIn: return localized("Built-in")
        case .airPlay: return localized("AirPlay")
        case .usb: return localized("USB")
        case .hdmi, .displayPort: return localized("Display")
        case .virtual: return localized("Virtual")
        case .bluetooth, .bluetoothLE: return localized("Bluetooth")
        case .other: return localized("Connected")
        }
    }
}

struct BatteryStatusRow: View {
    let battery: BatteryStatus
    let showPercentage: Bool

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 28, height: 28)
                .background(.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 8) {
                    Text(localized("Battery"))
                        .font(.system(size: 12.5, weight: .semibold))
                    Spacer(minLength: 8)
                    if let trailingValue {
                        Text(trailingValue)
                            .font(.system(size: 10.5, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                Text(detail)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 48)
        .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    var trailingValue: String? {
        guard showPercentage, let percentage = battery.percentage else { return nil }
        return localized("%d%%", percentage)
    }

    var detail: String {
        guard battery.isAvailable else { return localized("No internal battery") }
        if battery.isFullyCharged { return localized("Fully charged") }
        if battery.isCharging { return localized("Charging") }
        if battery.isLowPowerModeEnabled { return localized("Low Power Mode") }
        if battery.isPluggedIn { return localized("Power adapter connected") }
        return localized("Using battery power")
    }

    private var symbol: String {
        if battery.isCharging { return "battery.100percent.bolt" }
        if battery.isFullyCharged { return "battery.100percent" }
        switch battery.percentage ?? 0 {
        case 76...100: return "battery.100percent"
        case 51...75: return "battery.75percent"
        case 26...50: return "battery.50percent"
        default: return "battery.25percent"
        }
    }
}

#if DEBUG
private struct DebugStatusSimulatorView: View {
    let statusStore: SystemStatusStore
    @AppStorage(PreferenceKeys.batteryColorCoding) private var batteryColorCoding = false
    @ObservedObject private var adaptiveRingMonitor = AdaptiveRingMonitor.shared

    var body: some View {
        VStack(spacing: 5) {
            HStack {
                Label("Debug Simulator", systemImage: "hammer")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Menu("Simulate") {
                    Menu("Battery Level") {
                        ForEach(DebugBatteryLevel.allCases) { level in
                            Button(level.title) { statusStore.applyDebugBatteryLevel(level) }
                        }
                    }
                    Menu("Battery Power") {
                        ForEach(DebugPowerState.allCases) { powerState in
                            Button(powerState.rawValue) { statusStore.applyDebugPowerState(powerState) }
                        }
                    }
                    Menu("Low Power Mode") {
                        ForEach(DebugLowPowerMode.allCases) { lowPowerMode in
                            Button(lowPowerMode.rawValue) { statusStore.applyDebugLowPowerMode(lowPowerMode) }
                        }
                    }
                    Menu("Battery Color Coding") {
                        Button("Off") { batteryColorCoding = false }
                        Button("On") { batteryColorCoding = true }
                    }
                    Menu("Network") {
                        ForEach(DebugNetworkState.allCases) { networkState in
                            Button(networkState.rawValue) { statusStore.applyDebugNetworkState(networkState) }
                        }
                    }
                    Menu("Volume") {
                        ForEach(DebugVolumeState.allCases) { volumeState in
                            Button(volumeState.rawValue) { statusStore.applyDebugVolumeState(volumeState) }
                        }
                    }
                    Menu("Audio Connection") {
                        ForEach(DebugAudioDeviceState.allCases) { deviceState in
                            Button(deviceState.rawValue) { statusStore.applyDebugAudioDeviceState(deviceState) }
                        }
                    }
                    Divider()
                    Button("Restore Live Data") { statusStore.restoreLiveStatus() }
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }

            Divider()

            LabeledContent("Laptop Ring Mode", value: laptopRingModeLabel)
            LabeledContent("Charging session", value: chargingSessionLabel)
            LabeledContent("Adaptive telemetry lease", value: adaptiveRingMonitor.monitoringOwnerCount > 0 ? "Active" : "Inactive")
            LabeledContent("Adaptive monitor", value: adaptiveRingMonitor.isMonitoring ? "Running" : "Stopped")
            LabeledContent("Adaptive source", value: adaptiveRingMonitor.debugTestSource.rawValue)
            LabeledContent("Brightness", value: brightnessLabel)
            LabeledContent("Adaptive metric", value: adaptiveRingMonitor.state.diagnosticLabel)
            LabeledContent("Adaptive progress", value: adaptiveProgressLabel)
            LabeledContent("Final ring override", value: finalRingOverrideLabel)

        }
        .padding(.horizontal, 6)
        .frame(minHeight: 26)
    }

    private var laptopRingModeLabel: String {
        switch statusStore.laptopRingModeState.mode {
        case .battery: "Battery"
        case .adaptive: "Adaptive"
        }
    }

    private var chargingSessionLabel: String {
        guard let start = statusStore.laptopRingModeState.sessionStartPercentage,
              let target = statusStore.laptopRingModeState.targetPercentage
        else { return "None" }
        let waiting = statusStore.laptopRingModeState.isWaitingForFullChargeDelay ? " · waiting for full delay" : ""
        return "\(start)% → \(target)%\(waiting)"
    }

    private var brightnessLabel: String {
        guard let availability = adaptiveRingMonitor.brightnessSnapshot?.availability else { return "Sampling…" }
        switch availability {
        case .available(let value): return String(format: "%.0f%%", value * 100)
        case .unavailable: return "Unavailable"
        }
    }

    private var adaptiveProgressLabel: String {
        let target = AdaptiveRingVisualTarget(state: adaptiveRingMonitor.state).progress
        return String(format: "%.1f%%", target * 100)
    }

    private var finalRingOverrideLabel: String {
        guard statusStore.usesAdaptiveRing else { return "Battery Ring" }
        let target = AdaptiveRingVisualTarget(state: adaptiveRingMonitor.state).progress
        return String(format: "%.1f%%", target * 100)
    }
}
#endif
