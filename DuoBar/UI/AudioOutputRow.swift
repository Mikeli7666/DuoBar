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
    @State private var switchFailed = false

    var body: some View {
        Menu {
            if outputs.isEmpty {
                Text(localized("No output devices"))
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
                Button(localized("Bluetooth Settings…")) {
                    onOpenBluetoothSettings()
                }
                if switchFailed {
                    Text(localized("Unable to Switch Output"))
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
        .accessibilityHint(localized("Select audio output"))
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
