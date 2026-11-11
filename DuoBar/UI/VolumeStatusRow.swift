import SwiftUI

struct VolumeStatusRow: View {
    let volume: OutputVolumeStatus
    let hasOutputDevice: Bool
    let playbackDeviceIdentifier: String?
    let onSetVolume: (Double) -> Bool
    let onSetMuted: (Bool) -> Bool

    @State private var feedbackInteraction = VolumeFeedbackInteraction()

    var body: some View {
        // Layout follows the native Control Center Sound tile: title on top,
        // below it a thin track between a low and a high speaker glyph.
        // The low-volume glyph doubles as the mute button.
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(localized("Volume"))
                    .font(.system(size: 13, weight: .semibold))
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

            HStack(spacing: 8) {
                muteControl
                    .frame(width: 14, height: 14)

                if volume.isSettable, let level = volume.level {
                    NativeVolumeSlider(
                        level: level,
                        isMuted: volume.isMuted,
                        onChange: handleUserVolumeChange,
                        onEditingChanged: handleSliderEditingChanged
                    )
                    .accessibilityLabel(localized("Output volume"))
                    .accessibilityValue(stateText)

                    Image(systemName: "speaker.wave.3.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 18, height: 14)
                } else {
                    Text(hasOutputDevice ? localized("Controlled by device") : localized("Volume unavailable"))
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    Spacer(minLength: 0)
                }
            }
            .frame(height: 14)
        }
        .padding(.horizontal, 10)
        .padding(.top, 9)
        .frame(height: 62, alignment: .top)
        .popoverCardBackground(cornerRadius: 11, fillOpacity: 0.045)
    }

    @ViewBuilder
    private var muteControl: some View {
        if volume.isMuteSettable {
            Button {
                handleUserMuteChange()
            } label: {
                lowVolumeImage
                    .frame(width: 18, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(volume.isMuted ? localized("Unmute") : localized("Mute"))
            .accessibilityLabel(volume.isMuted ? localized("Unmute output") : localized("Mute output"))
        } else {
            lowVolumeImage
        }
    }

    private var lowVolumeImage: some View {
        let silent = volume.isMuted || volume.percentage == 0
        return Image(systemName: silent ? "speaker.slash.fill" : "speaker.fill")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)
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

/// Slider in the style of Control Center's Display / Sound rows, measured from
/// the native recording: a thin fully rounded track, solid white up to the
/// knob and a faint white remainder, and a small white rounded-rectangle knob.
private struct NativeVolumeSlider: View {
    let level: Double
    let isMuted: Bool
    let onChange: (Double) -> Void
    let onEditingChanged: (Bool) -> Void

    @State private var isDragging = false

    private let trackHeight: CGFloat = 4.5
    private let knobSize = CGSize(width: 18, height: 14)
    private let hitHeight: CGFloat = 24

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let travel = max(width - knobSize.width, 1)
            let clamped = CGFloat(min(max(level, 0), 1))
            let knobCenter = knobSize.width / 2 + clamped * travel
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(.white.opacity(0.28))
                    .frame(height: trackHeight)
                Capsule(style: .continuous)
                    .fill(.white.opacity(isMuted ? 0.35 : 1))
                    .frame(width: knobCenter, height: trackHeight)
                RoundedRectangle(cornerRadius: 6.5, style: .continuous)
                    .fill(.white.opacity(isMuted ? 0.55 : 1))
                    .frame(width: knobSize.width, height: knobSize.height)
                    .offset(x: knobCenter - knobSize.width / 2)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            onEditingChanged(true)
                        }
                        let raw = (value.location.x - knobSize.width / 2) / travel
                        onChange(Double(min(max(raw, 0), 1)))
                    }
                    .onEnded { _ in
                        isDragging = false
                        onEditingChanged(false)
                    }
            )
        }
        .frame(height: hitHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: onChange(min(level + 0.1, 1))
            case .decrement: onChange(max(level - 0.1, 0))
            @unknown default: break
            }
        }
    }
}
