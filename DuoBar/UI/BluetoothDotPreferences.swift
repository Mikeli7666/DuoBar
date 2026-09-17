import SwiftUI

struct BluetoothDotPreferences: DynamicProperty {
    @AppStorage(PreferenceKeys.bluetoothDotMode) var mode: BluetoothDotMode = .power
    @AppStorage(PreferenceKeys.bluetoothDotSlot1) var slot1 = ""
    @AppStorage(PreferenceKeys.bluetoothDotSlot2) var slot2 = ""
    @AppStorage(PreferenceKeys.bluetoothDotSlot3) var slot3 = ""
    @AppStorage(PreferenceKeys.bluetoothDotSlot4) var slot4 = ""
    @AppStorage(PreferenceKeys.bluetoothDotBatteryDevice) var batteryDeviceID = ""

    var configuration: BluetoothDotConfiguration {
        BluetoothDotConfiguration(mode: mode, pinnedDeviceIDs: [slot1, slot2, slot3, slot4], batteryDeviceID: batteryDeviceID)
    }

    func slotBinding(_ index: Int) -> Binding<String> {
        switch index {
        case 0: $slot1
        case 1: $slot2
        case 2: $slot3
        default: $slot4
        }
    }
}

struct BluetoothDotModePicker: View {
    private var preferences = BluetoothDotPreferences()

    var body: some View {
        Picker("Dots show", selection: preferences.$mode) {
            ForEach(BluetoothDotMode.allCases) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.menu)
    }
}

struct BluetoothDotSettingsView: View {
    let bluetooth: BluetoothStatus
    private var preferences = BluetoothDotPreferences()

    var body: some View {
        BluetoothDotModePicker()
        Text(preferences.mode.explanation)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

        if preferences.mode == .pinnedDevices {
            ForEach(0..<4, id: \.self) { index in
                devicePicker("Dot \(index + 1)", selection: preferences.slotBinding(index), slot: index)
            }
        } else if preferences.mode == .accessoryBattery {
            devicePicker("Accessory", selection: preferences.$batteryDeviceID)
            Text("Battery readings include supported headphones and input devices. AirPods use the lower reported earbud level; the case is excluded. macOS may not provide every reading.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(BluetoothDotPresentation(bluetooth: bluetooth, configuration: preferences.configuration).summary)
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
        }
        if bluetooth.devices.isEmpty && (preferences.mode == .pinnedDevices || preferences.mode == .accessoryBattery) {
            Text("No paired devices available. Pair a device in Bluetooth Settings, then return here.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func devicePicker(_ title: String, selection: Binding<String>, slot: Int? = nil) -> some View {
        Picker(title, selection: selection) {
            Text("None").tag("")
            if !selection.wrappedValue.isEmpty && !bluetooth.devices.contains(where: { $0.id == selection.wrappedValue }) {
                Text("Unavailable device").tag(selection.wrappedValue)
            }
            ForEach(bluetooth.devices.filter { device in
                slot == nil || device.id == selection.wrappedValue || !preferences.configuration.slots.contains(device.id)
            }) { device in
                Text(device.name).tag(device.id)
            }
        }
        .pickerStyle(.menu)
    }
}
