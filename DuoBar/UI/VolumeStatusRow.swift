import SwiftUI

struct VolumeStatusRow: View {
    let volume: OutputVolumeStatus
    let hasOutputDevice: Bool
    let playbackDeviceIdentifier: String?
    let onSetVolume: (Double) -> Bool
    let onSetMuted: (Bool) -> Bool

    @State private var feedbackInteraction = VolumeFeedbackInteraction()

    var body: some View {
        HStack(spacing: 11) {
            muteControl
                .frame(width: 28, height: 28)
                .background(.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(localized("Volume"))
                        .font(.system(size: 12.5, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                    Spacer()
                    Text(stateText)
                        .font(.system(size: 10.5, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                if volume.isSettable, let level = volume.level {
                    Slider(
                        value: Binding(
                            get: { level },
                            set: handleUserVolumeChange
                        ),
                        in: 0...1,
                        onEditingChanged: handleSliderEditingChanged
                    )
                    .controlSize(.mini)
                    .accessibilityLabel(localized("Output volume"))
                    .accessibilityValue(stateText)
                } else {
                    Text(hasOutputDevice ? localized("Controlled by device") : localized("Volume unavailable"))
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 54)
        .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    @ViewBuilder
    private var muteControl: some View {
        if volume.isMuteSettable {
            Button {
                handleUserMuteChange()
            } label: {
                Image(systemName: volumeSymbol)
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(volume.isMuted ? localized("Unmute") : localized("Mute"))
            .accessibilityLabel(volume.isMuted ? localized("Unmute output") : localized("Mute output"))
        } else {
            Image(systemName: volumeSymbol)
                .font(.system(size: 13, weight: .semibold))
        }
    }

    private var volumeSymbol: String {
        guard let percentage = volume.percentage else { return "speaker" }
        if volume.isMuted || percentage == 0 { return "speaker.slash.fill" }
        switch percentage {
        case 1...33: return "speaker.wave.1"
        case 34...66: return "speaker.wave.2"
        default: return "speaker.wave.3"
        }
    }

    private var stateText: String {
        if volume.isMuted { return localized("Muted") }
        return volume.percentage.map { localized("%d%%", $0) } ?? "—"
    }

    private func handleUserVolumeChange(_ level: Double) {
        beginSliderInteractionIfNeeded()
        var interaction = feedbackInteraction
        guard feedbackInteraction.allowsVolumeUpdates else {
            interaction.recordVolumeUpdate(
                previousStatus: volume,
                requestedLevel: level,
                writeSucceeded: false
            )
            $feedbackInteraction.wrappedValue = interaction
            return
        }

        let writeSucceeded = onSetVolume(level)
        interaction.recordVolumeUpdate(
            previousStatus: volume,
            requestedLevel: level,
            writeSucceeded: writeSucceeded
        )
        $feedbackInteraction.wrappedValue = interaction
    }

    private func handleSliderEditingChanged(_ isEditing: Bool) {
        if isEditing {
            beginSliderInteractionIfNeeded()
            return
        }
        var interaction = feedbackInteraction
        guard interaction.endEditing() else {
            $feedbackInteraction.wrappedValue = interaction
            return
        }
        $feedbackInteraction.wrappedValue = interaction
        VolumeFeedbackSound.play(on: playbackDeviceIdentifier)
    }

    private func beginSliderInteractionIfNeeded() {
        var interaction = feedbackInteraction
        interaction.beginEditing(previousStatus: volume) {
            onSetMuted(false)
        }
        $feedbackInteraction.wrappedValue = interaction
    }

    private func handleUserMuteChange() {
        let writeSucceeded = onSetMuted(!volume.isMuted)
        var interaction = feedbackInteraction
        guard interaction.shouldPlayForUnmute(
            previousStatus: volume,
            writeSucceeded: writeSucceeded
        ) else {
            $feedbackInteraction.wrappedValue = interaction
            return
        }
        $feedbackInteraction.wrappedValue = interaction

        VolumeFeedbackSound.play(on: playbackDeviceIdentifier)
    }
}
