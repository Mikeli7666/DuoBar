import SwiftUI

struct WiFiControlView: View {
    @ObservedObject var statusStore: SystemStatusStore
    @ObservedObject var controls: WiFiControls
    let openSettings: () -> Void
    let openLocationSettings: () -> Void
    @State private var selectedNetwork: WiFiNetworkOption?
    @State private var password = ""

    private var wifi: WiFiStatus { statusStore.status.wifi }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Wi-Fi", isOn: Binding(
                get: { wifi.isPoweredOn },
                set: { enabled in
                    selectedNetwork = nil
                    password = ""
                    Task {
                        await controls.setPower(enabled)
                        statusStore.refresh()
                    }
                }
            ))
            .disabled(controls.isBusy || !wifi.isAvailable)

            if wifi.isPoweredOn {
                if wifi.nameAccess == .authorized {
                    networkList
                } else {
                    Text("macOS requires Location access to list Wi-Fi network names.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if wifi.nameAccess == .notDetermined {
                        Button("Allow Network Name Access…") { statusStore.requestWiFiSSIDAccess() }
                    } else {
                        Button("Location Services Settings…", action: openLocationSettings)
                    }
                }
            }

            if controls.isBusy {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.mini)
                    Text("Working…").foregroundStyle(.secondary)
                }
            }
            if let error = controls.errorMessage {
                Text(error).foregroundStyle(.red).textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button("More Wi-Fi Settings…", action: openSettings)
        }
        .font(.system(size: 11.5))
        .padding(.horizontal, 10)
        .task { await scanIfAllowed() }
        .onChange(of: wifi.nameAccess) { _, _ in
            selectedNetwork = nil
            password = ""
            Task { await scanIfAllowed() }
        }
        .onChange(of: wifi.isPoweredOn) { _, _ in
            selectedNetwork = nil
            password = ""
            Task { await scanIfAllowed() }
        }
        .onDisappear { password = "" }
    }

    private var networkList: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Nearby Networks").foregroundStyle(.secondary)
                Spacer()
                Button("Refresh") {
                    selectedNetwork = nil
                    password = ""
                    Task { await controls.scan() }
                }
                .disabled(controls.isBusy)
            }
            if !controls.networks.isEmpty {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(controls.networks) { network in
                            Button {
                                password = ""
                                selectedNetwork = network
                            } label: {
                                HStack {
                                    Image(systemName: wifi.ssid == network.name ? "checkmark" : "wifi")
                                        .frame(width: 16)
                                    Text(network.name).lineLimit(1)
                                    Spacer()
                                    if network.security != .open {
                                        Image(systemName: "lock.fill")
                                    }
                                }
                                .padding(5)
                                .contentShape(Rectangle())
                                .background(selectedNetwork?.id == network.id ? Color.accentColor.opacity(0.12) : .clear,
                                            in: RoundedRectangle(cornerRadius: 5))
                            }
                            .buttonStyle(.plain)
                            .disabled(controls.isBusy || wifi.ssid == network.name)
                            .help(network.name)
                        }
                    }
                }
                .frame(height: min(CGFloat(controls.networks.count) * 29, 145))
            } else if controls.hasScanned && !controls.isBusy {
                Text("No named networks found. Try Refresh or Wi-Fi Settings.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let network = selectedNetwork {
                Text(network.name).fontWeight(.medium).lineLimit(1)
                if network.security == .systemSettings {
                    Text("This network needs setup in Wi-Fi Settings.").foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    if network.security == .personal {
                        SecureField("Network password", text: $password)
                            .textFieldStyle(.roundedBorder)
                            .disabled(controls.isBusy)
                    }
                    Button("Join Network") {
                        let enteredPassword = password
                        password = ""
                        Task {
                            if await controls.join(network, password: enteredPassword) {
                                selectedNetwork = nil
                            }
                            statusStore.refresh()
                        }
                    }
                    .disabled(controls.isBusy || (network.security == .personal && password.isEmpty))
                }
            }
        }
    }

    private func scanIfAllowed() async {
        if wifi.isPoweredOn && wifi.nameAccess == .authorized {
            await controls.scan()
        }
    }
}

struct BluetoothControlView: View {
    @ObservedObject var statusStore: SystemStatusStore
    @ObservedObject var controls: BluetoothControls
    var onOpenDuoSettings: () -> Void = {}
    let openSettings: () -> Void
    private var dotPreferences = BluetoothDotPreferences()

    private var bluetooth: BluetoothStatus { statusStore.status.bluetooth }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !bluetooth.isPoweredOn {
                Text("Turn on Bluetooth in Bluetooth Settings to connect devices.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else if bluetooth.devices.isEmpty {
                Text("No paired devices are available to DuoBar.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(bluetooth.devices) { device in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(device.name).lineLimit(1).help(device.name)
                                    Text(device.isConnected ? "Connected" : "Not connected")
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if controls.busyDeviceID == device.id {
                                    ProgressView().controlSize(.mini)
                                } else {
                                    Button(device.isConnected ? "Disconnect" : "Connect") {
                                        Task {
                                            await controls.setConnected(!device.isConnected, device: device)
                                            statusStore.refresh()
                                        }
                                    }
                                    .disabled(controls.busyDeviceID != nil)
                                }
                            }
                        }
                    }
                }
                .frame(height: min(CGFloat(bluetooth.devices.count) * 40, 160))
            }
            if let error = controls.errorMessage {
                Text(error).foregroundStyle(.red).textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("Some accessories need Bluetooth Settings to connect or pair.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("Refresh") { statusStore.refresh() }
                    .disabled(controls.busyDeviceID != nil)
                Spacer()
                Button("More Bluetooth Settings…", action: openSettings)
            }
            Divider()
            BluetoothDotModePicker()
            Text(dotSummary)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if dotPreferences.mode == .pinnedDevices || dotPreferences.mode == .accessoryBattery {
                SettingsLink { Text("Choose Dot Devices…") }
                    .simultaneousGesture(TapGesture().onEnded {
                        NSApp.activate(ignoringOtherApps: true)
                        onOpenDuoSettings()
                    })
            }
        }
        .font(.system(size: 11.5))
        .padding(.horizontal, 10)
    }

    private var dotSummary: String {
        let configuration = dotPreferences.configuration
        let presentation = BluetoothDotPresentation(bluetooth: bluetooth, configuration: configuration)
        if configuration.mode == .pinnedDevices, bluetooth.isAvailable, bluetooth.isPoweredOn {
            let assigned = configuration.slots.filter { !$0.isEmpty }.count
            let connected = presentation.dots.filter { $0 == .on }.count
            return "\(connected) of \(assigned) pinned devices connected."
        }
        return presentation.summary
    }
}

struct BatteryControlView: View {
    @AppStorage(PreferenceKeys.showBatteryPercentage) private var showBatteryPercentage = true
    @AppStorage(PreferenceKeys.showMenuBarBatteryPercentage) private var showMenuBarBatteryPercentage = false
    let openSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Percentage in menu bar", isOn: $showMenuBarBatteryPercentage)
            Toggle("Percentage in dropdown", isOn: $showBatteryPercentage)
            Text("Power modes and battery health are managed in Battery Settings.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("More Battery Settings…", action: openSettings)
        }
        .toggleStyle(.checkbox)
        .font(.system(size: 11.5))
        .padding(.horizontal, 10)
    }
}
