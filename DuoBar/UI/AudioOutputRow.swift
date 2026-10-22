import SwiftUI

struct AudioOutputRow: View {
    let symbol: String
    let title: String
    let detail: String
    let stateText: String
    let outputs: [AudioDeviceStatus]
    let selectedUID: String?
    let onSelect: (String) -> Bool
    let onOpenSoundSettings: () -> Void
    let onOpenBluetoothSettings: () -> Void
    var emptyText = localized("No output devices")
    var failureText = localized("Unable to Switch Output")
    var hint = localized("Select audio output")
    var showsBluetoothSettings = true
    @State private var switchFailed = false

    var body: some View {
        Menu {
            if outputs.isEmpty {
                Text(emptyText)
            } else {
                Picker(selection: selection) {
                    ForEach(outputs) { device in
                        Text(device.name).tag(device.uid)
                    }
                } label: {
                    Text(title)
                }
                .pickerStyle(.inline)
            }

            Divider()

                Button(localized("Sound Settings…")) {
                    onOpenSoundSettings()
                }
                if showsBluetoothSettings {
                    Button(localized("Bluetooth Settings…")) {
                        onOpenBluetoothSettings()
                    }
                }
                if switchFailed {
                    Text(failureText)
                        .foregroundStyle(.secondary)
                }
        } label: {
            StatusRow(
                symbol: symbol,
                title: title,
                detail: detail,
                stateText: stateText,
                tint: .primary,
                accessory: .menu
            )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(maxWidth: .infinity)
        .accessibilityLabel(title)
        .accessibilityValue(detail)
        .accessibilityHint(hint)
    }

    private var selection: Binding<String> {
        Binding(
            get: { selectedUID ?? "" },
            set: { uid in
                guard !uid.isEmpty, uid != selectedUID else { return }
                switchFailed = !onSelect(uid)
            }
        )
    }
}
