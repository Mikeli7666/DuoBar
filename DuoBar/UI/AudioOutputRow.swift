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
    @State private var isPresented = false
    @State private var switchFailed = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            StatusRow(
                symbol: symbol,
                title: title,
                detail: detail,
                stateText: stateText,
                tint: .primary,
                accessory: .disclosure
            )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .accessibilityLabel(title)
        .accessibilityValue(detail)
        .accessibilityHint(hint)
        .popover(isPresented: $isPresented, arrowEdge: .trailing) {
            AudioDevicePickerPopover(
                title: title,
                devices: outputs,
                selectedUID: selectedUID,
                emptyText: emptyText,
                failureText: switchFailed ? failureText : nil,
                showsBluetoothSettings: showsBluetoothSettings,
                isInput: !showsBluetoothSettings,
                onSelect: select,
                onOpenSoundSettings: {
                    isPresented = false
                    onOpenSoundSettings()
                },
                onOpenBluetoothSettings: {
                    isPresented = false
                    onOpenBluetoothSettings()
                }
            )
        }
    }

    private func select(_ uid: String) {
        guard uid != selectedUID else { return }
        switchFailed = !onSelect(uid)
    }
}

private struct AudioDevicePickerPopover: View {
    let title: String
    let devices: [AudioDeviceStatus]
    let selectedUID: String?
    let emptyText: String
    let failureText: String?
    let showsBluetoothSettings: Bool
    let isInput: Bool
    let onSelect: (String) -> Void
    let onOpenSoundSettings: () -> Void
    let onOpenBluetoothSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))

            Divider()

            content

            Divider()

            HStack {
                Button(localized("Sound Settings…"), action: onOpenSoundSettings)
                Spacer()
                if showsBluetoothSettings {
                    Button(localized("Bluetooth Settings…"), action: onOpenBluetoothSettings)
                }
            }
            .controlSize(.small)
        }
        .padding(12)
        .frame(width: 300)
    }

    @ViewBuilder
    private var content: some View {
        if devices.isEmpty {
            Label(emptyText, systemImage: isInput ? "mic.slash" : "speaker.slash")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 76)
        } else {
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(devices) { device in
                        deviceButton(device)
                    }
                }
            }
            .frame(maxHeight: 252)

            if let failureText {
                Text(failureText)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func deviceButton(_ device: AudioDeviceStatus) -> some View {
        let isCurrent = device.uid == selectedUID
        return Button {
            onSelect(device.uid)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: symbolName(for: device))
                    .frame(width: 18)
                    .accessibilityHidden(true)

                Text(device.name)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer(minLength: 8)

                if isCurrent {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .semibold))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 6)
        .frame(height: 30)
        .disabled(isCurrent)
        .accessibilityLabel(device.name)
        .accessibilityHint(isCurrent ? "" : hintForSelection)
    }

    private var hintForSelection: String {
        isInput ? localized("Select audio input") : localized("Select audio output")
    }

    private func symbolName(for device: AudioDeviceStatus) -> String {
        if isInput {
            return "mic"
        }

        switch device.category {
        case .airPods: return "airpodspro"
        case .headphones, .bluetoothAudio: return "headphones"
        case .displayAudio: return "display"
        case .usbAudio, .builtInSpeaker, .other: return "speaker.wave.2"
        }
    }
}
