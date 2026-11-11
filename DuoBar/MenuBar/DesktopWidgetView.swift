import SwiftUI

/// Modes the desktop widget cycles through on click. Batches ship in
/// order — `.standard` and `.adaptive` first, `.custom` second; `.music`
/// appends last — raw values must never be reused or reordered, and
/// cycling uses `allCases.count`, so new modes join the cycle
/// automatically.
enum DesktopWidgetMode: Int, CaseIterable {
    case standard = 0
    case adaptive = 1
    case custom = 2

    /// Name flashed briefly on the widget face when the mode is entered.
    var title: String {
        switch self {
        case .standard: return "Standard"
        case .adaptive: return "Adaptive Ring"
        case .custom: return "Custom"
        }
    }

    /// Modes reachable in the current release. Adaptive and Custom are
    /// built but ship in a later update: cycling, rendering and Settings
    /// all clamp to this list, so widening it is the only change needed
    /// when they ship.
    static var releasedModes: [DesktopWidgetMode] { [.standard] }
}

/// What the ring itself reports in custom mode. `.battery` keeps the
/// full battery presentation (charging bolt, colour roles); every other
/// source draws as a plain progress arc with the Adaptive Ring's colour
/// for that metric. Raw values persist — never reuse or reorder them.
enum DesktopWidgetRingSource: Int, CaseIterable {
    case battery = 0
    case cpu = 1
    case memory = 2
    case thermal = 3
    case brightness = 4
    case wifi = 5

    /// Settings-picker label.
    var title: String {
        switch self {
        case .battery: return "Battery"
        case .cpu: return "CPU"
        case .memory: return "Memory"
        case .thermal: return "Thermal"
        case .brightness: return "Brightness"
        case .wifi: return "Wi-Fi Signal"
        }
    }
}

/// User-selectable widget size. The raw values persist — never reuse or
/// reorder them.
enum DesktopWidgetSize: Int, CaseIterable {
    case small = 0
    case medium = 1
    case large = 2

    var scale: CGFloat {
        switch self {
        case .small: return 0.8
        case .medium: return 1.0
        case .large: return 1.3
        }
    }

    /// Settings-picker label.
    var title: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        }
    }
}

/// What the four dots under the ring report in custom mode. Raw values
/// persist in UserDefaults — never reuse or reorder them.
enum DesktopWidgetDotsSource: Int, CaseIterable {
    case volume = 0
    case battery = 1
    case cpu = 2
    case memory = 3
    case thermal = 4
    case wifi = 5

    /// Settings-picker and caption label.
    var title: String {
        switch self {
        case .volume: return "Volume"
        case .battery: return "Battery"
        case .cpu: return "CPU"
        case .memory: return "Memory"
        case .thermal: return "Thermal"
        case .wifi: return "Wi-Fi Signal"
        }
    }
}

/// What sits in the glyph's centre in custom mode. `.network` means no
/// override: the centre follows the live connection, exactly like the
/// menu bar. Raw values persist — never reuse or reorder them.
enum DesktopWidgetCenterSource: Int, CaseIterable {
    case network = 0
    case cpu = 1
    case memory = 2
    case thermal = 3
    case brightness = 4

    /// Settings-picker label.
    var title: String {
        switch self {
        case .network: return "Network"
        case .cpu: return "CPU"
        case .memory: return "Memory"
        case .thermal: return "Thermal"
        case .brightness: return "Brightness"
        }
    }
}

/// The desktop widget's face: the real Duo glyph, large, on a glass card.
///
/// Mode 1 (standard) resolves the glyph exactly like the menu bar's
/// battery presentation; mode 2 (adaptive) forces the Adaptive Ring with
/// the live performance monitor, colour-coded unconditionally (the
/// Settings colour-coding toggle governs the menu bar; on this showcase
/// surface the colour IS the signal), with the active metric's symbol
/// held in the centre. Mode 3 (custom) lets the user choose what the
/// ring reports, what the four dots report and which symbol sits in the
/// centre; the dots are driven by feeding the glyph a status copy whose
/// volume carries the chosen metric's level, so the dot geometry and
/// thresholds stay the menu bar's own. The percentage is deliberately
/// not drawn inside the ring gap — the glyph scales its 8 pt text by
/// raster, which softens at this size — the caption below renders it
/// natively instead.
struct DesktopWidgetView: View {
    @ObservedObject var statusStore: SystemStatusStore
    @ObservedObject private var adaptiveRingMonitor = AdaptiveRingMonitor.shared
    @AppStorage(PreferenceKeys.desktopWidgetMode) private var modeRaw = DesktopWidgetMode.standard.rawValue
    @AppStorage(PreferenceKeys.desktopWidgetCustomDots) private var customDotsRaw = DesktopWidgetDotsSource.volume.rawValue
    @AppStorage(PreferenceKeys.desktopWidgetCustomCenter) private var customCenterRaw = DesktopWidgetCenterSource.network.rawValue
    @AppStorage(PreferenceKeys.desktopWidgetCustomRing) private var customRingRaw = DesktopWidgetRingSource.battery.rawValue
    @AppStorage(PreferenceKeys.desktopWidgetSize) private var widgetSizeRaw = DesktopWidgetSize.medium.rawValue
    @AppStorage(PreferenceKeys.animationsEnabled) private var animationsEnabled = true
    @AppStorage(PreferenceKeys.batteryColorCoding) private var batteryColorCoding = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var adaptivePresentation = AdaptiveRingPresentationState()
    @State private var adaptiveTransition: AdaptiveRingPresentationTransition = .none
    @State private var monitorOwner = UUID()
    @State private var toastName: String?
    @State private var toastGeneration = 0

    private var mode: DesktopWidgetMode {
        let stored = DesktopWidgetMode(rawValue: modeRaw) ?? .standard
        return DesktopWidgetMode.releasedModes.contains(stored) ? stored : .standard
    }

    private var dotsSource: DesktopWidgetDotsSource {
        DesktopWidgetDotsSource(rawValue: customDotsRaw) ?? .volume
    }

    private var centerSource: DesktopWidgetCenterSource {
        DesktopWidgetCenterSource(rawValue: customCenterRaw) ?? .network
    }

    private var ringSource: DesktopWidgetRingSource {
        DesktopWidgetRingSource(rawValue: customRingRaw) ?? .battery
    }

    private var sizeScale: CGFloat {
        (DesktopWidgetSize(rawValue: widgetSizeRaw) ?? .medium).scale
    }

    /// The glyph's visual extent on the card, in points.
    private var glyphExtent: CGFloat { 102 * sizeScale }

    private var motionAllowed: Bool {
        animationsEnabled && !reduceMotion
    }

    /// Metrics the glyph is drawn with. This mirrors the film stage's
    /// approach (see DuoStatusView): grow the DESIGN fields and leave
    /// overallSize at the menu-bar value, so the glyph draws natively at
    /// widget size and its root scaleEffect(overallSize / canvasSize)
    /// scales DOWN — sharp. sized(_:) grows only overallSize, which
    /// upscales the small native render; the SF Symbol centres (CPU,
    /// memorychip…) came out soft that way.
    private var glyphMetrics: DuoGlyphMetrics {
        let factor = glyphExtent / DuoGlyphMetrics.standard.overallSize
        var metrics = DuoGlyphMetrics.standard
        metrics.ringDiameter *= factor
        metrics.ringLineWidth *= factor
        metrics.wifiSymbolSize *= factor
        metrics.wifiYOffset *= factor
        metrics.dotDiameter *= factor
        metrics.dotSpacing *= factor
        metrics.dotYOffset *= factor
        metrics.ringYOffset *= factor
        return metrics
    }

    /// Mode changes cross through a blur, like a native widget refresh:
    /// the old face blurs and fades out while the new one sharpens in.
    private var modeTransition: AnyTransition {
        guard motionAllowed else { return .opacity }
        return .modifier(
            active: WidgetModeBlurModifier(radius: 12, opacity: 0),
            identity: WidgetModeBlurModifier(radius: 0, opacity: 1)
        )
    }

    /// The performance monitor runs in adaptive mode (it IS the data)
    /// and in custom mode (CPU / memory / thermal dots or centre read
    /// its snapshots). Standard mode never acquires it.
    private var needsMonitor: Bool {
        mode == .adaptive || mode == .custom
    }

    /// The status the glyph renders. In custom mode with a non-volume
    /// dots source, this is a copy whose volume level carries the chosen
    /// metric's fraction, so DuoGlyphState derives the dot count from it
    /// with the menu bar's own thresholds. A nil fraction (source
    /// unavailable) yields a nil dot count, which the glyph draws as
    /// "no reading" — never as the real volume.
    private var effectiveStatus: SystemStatus {
        guard mode == .custom, dotsSource != .volume else {
            return statusStore.status
        }
        var status = statusStore.status
        status.audio.volume = OutputVolumeStatus(
            level: dotsFraction,
            isMuted: false,
            isSettable: false
        )
        return status
    }

    /// The fraction the custom dots currently report, on each source's
    /// natural 0–1 scale. Thermal is a four-step state, mapped onto
    /// quarters (nominal ¼ … critical 4⁄4).
    private var dotsFraction: Double? {
        switch dotsSource {
        case .volume:
            return statusStore.status.audio.volume.level
        case .battery:
            return statusStore.status.battery.percentage.map { Double($0) / 100 }
        case .cpu:
            return adaptiveRingMonitor.performanceSnapshot?.cpuLoad
        case .memory:
            return adaptiveRingMonitor.performanceSnapshot?.memory.map { 1 - $0.availableHeadroom }
        case .thermal:
            return adaptiveRingMonitor.performanceSnapshot.map {
                Double($0.thermalState.rawValue + 1) / 4
            }
        case .wifi:
            return statusStore.status.network.signalStrength
        }
    }

    /// The fraction a non-battery custom ring currently reports, on the
    /// same natural scales as dotsFraction.
    private var ringFraction: Double? {
        switch ringSource {
        case .battery:
            return nil
        case .cpu:
            return adaptiveRingMonitor.performanceSnapshot?.cpuLoad
        case .memory:
            return adaptiveRingMonitor.performanceSnapshot?.memory.map { 1 - $0.availableHeadroom }
        case .thermal:
            return adaptiveRingMonitor.performanceSnapshot.map {
                Double($0.thermalState.rawValue + 1) / 4
            }
        case .brightness:
            if case .available(let value) = adaptiveRingMonitor.brightnessSnapshot?.availability {
                return value
            }
            return nil
        case .wifi:
            return statusStore.status.network.signalStrength
        }
    }

    var body: some View {
        // Capture the State bindings once: result-builder modifier
        // closures must not capture the projections directly (same
        // constraint DuoStatusView documents).
        let adaptivePresentationBinding = $adaptivePresentation
        let adaptiveTransitionBinding = $adaptiveTransition

        ZStack {
            RoundedRectangle(cornerRadius: 30 * sizeScale, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 30 * sizeScale, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                }

            VStack(spacing: 7 * sizeScale) {
                // The glyph's layout box stays at the menu-bar size (its
                // design fields carry the magnification — see
                // glyphMetrics), so it is centred in a fixed visual
                // frame, the same arrangement the film stage uses.
                DuoGlyphView(
                    status: effectiveStatus,
                    presentation: .normal,
                    metrics: glyphMetrics,
                    animationsEnabled: animationsEnabled,
                    ringPresentation: ringPresentation,
                    centerStateOverride: centerOverride,
                    ringTransitionAnimation: ringAnimation,
                    usesCustomRingTransition: mode == .adaptive,
                    ringColorOverride: ringColor,
                    batteryColorCodingEnabled: batteryColorCoding,
                    showBatteryPercentage: false
                )
                .frame(width: glyphExtent, height: glyphExtent)

                Text(caption)
                    .font(.system(size: max(10, 12 * sizeScale), weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .id(mode)
            .transition(modeTransition)
        }
        .animation(motionAllowed ? .easeInOut(duration: 0.3) : nil, value: mode)
        .animation(.easeInOut(duration: 0.25), value: toastName)
        .overlay(alignment: .top) {
            if let toastName {
                Text(toastName)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background {
                        Capsule().fill(.ultraThinMaterial)
                    }
                    .overlay {
                        Capsule().strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                    }
                    .padding(.top, 7 * sizeScale)
                    .transition(.opacity.combined(with: .offset(y: -4)))
            }
        }
        .onAppear {
            if needsMonitor { acquireMonitor() }
        }
        .onDisappear {
            adaptiveRingMonitor.release(owner: monitorOwner)
        }
        .onChange(of: mode) { newMode in
            if needsMonitor {
                acquireMonitor()
            } else {
                adaptiveRingMonitor.release(owner: monitorOwner)
            }
            flashModeName(newMode)
        }
        .onChange(of: adaptiveRingMonitor.state) { newState in
            guard mode == .adaptive else { return }
            var presentation = adaptivePresentationBinding.wrappedValue
            let transition = presentation.retarget(to: newState)
            adaptivePresentationBinding.wrappedValue = presentation
            adaptiveTransitionBinding.wrappedValue = transition
        }
    }

    private var ringPresentation: DuoPersistentRingPresentation {
        if mode == .custom, ringSource != .battery {
            // An unavailable source draws an empty ring, never a
            // stand-in value.
            return .adaptive(progress: ringFraction ?? 0)
        }
        return DuoPersistentRingPresentationResolver.resolve(
            mode: mode == .adaptive ? .adaptive : .battery,
            battery: statusStore.status.battery,
            adaptiveProgress: adaptivePresentation.displayedProgress,
            batteryColorCodingEnabled: batteryColorCoding
        )
    }

    private var centerOverride: DuoCenterState? {
        switch mode {
        case .standard:
            return nil
        case .adaptive:
            switch AdaptiveRingSourceIdentity(state: adaptiveRingMonitor.state) {
            case .cpu: return .performanceCPU
            case .memory: return .performanceMemory
            case .thermal: return .performanceThermal
            case .brightness: return .adaptiveBrightness
            case .neutral: return nil
            }
        case .custom:
            switch centerSource {
            case .network: return nil
            case .cpu: return .performanceCPU
            case .memory: return .performanceMemory
            case .thermal: return .performanceThermal
            case .brightness: return .adaptiveBrightness
            }
        }
    }

    private var ringColor: Color? {
        if mode == .custom, ringSource != .battery {
            // The custom ring reports one chosen metric, so its colour
            // is that metric's Adaptive Ring colour outright — the
            // resolver's "only when the engine agrees" rule is the menu
            // bar's policy, not this surface's.
            let role: AdaptiveRingColorRole
            switch ringSource {
            case .cpu: role = .cpu
            case .memory: role = .memory
            case .thermal: role = .thermal
            case .brightness: role = .brightness
            case .battery, .wifi: return nil
            }
            return AdaptiveRingColorPresentation(role: role, intensity: 0.85).color
        }
        guard mode == .adaptive else { return nil }
        return AdaptiveRingColorResolver.resolve(
            state: adaptiveRingMonitor.state,
            decision: adaptiveRingMonitor.performanceDecision,
            colorCodingEnabled: true
        ).color
    }

    private var ringAnimation: Animation? {
        guard mode == .adaptive else { return nil }
        let duration = adaptiveTransition.effectiveDuration(
            animationsEnabled: animationsEnabled,
            reduceMotion: reduceMotion
        )
        return duration > 0 ? .timingCurve(0.4, 0, 0.2, 1, duration: duration) : nil
    }

    private var caption: String {
        switch mode {
        case .standard:
            return statusStore.status.battery.percentage.map { "\($0)%" } ?? "—"
        case .adaptive:
            switch AdaptiveRingSourceIdentity(state: adaptiveRingMonitor.state) {
            case .cpu: return "CPU"
            case .memory: return "Memory"
            case .thermal: return "Thermal"
            case .brightness: return "Brightness"
            case .neutral: return "Idle"
            }
        case .custom:
            // The caption reports the dots source: it is the number the
            // four dots are quantising, so label and value travel
            // together.
            switch dotsSource {
            case .volume:
                return percentCaption("Volume", statusStore.status.audio.volume.level)
            case .battery:
                return statusStore.status.battery.percentage.map { "Battery \($0)%" } ?? "Battery —"
            case .cpu:
                return percentCaption("CPU", adaptiveRingMonitor.performanceSnapshot?.cpuLoad)
            case .memory:
                return percentCaption(
                    "Memory",
                    adaptiveRingMonitor.performanceSnapshot?.memory.map { 1 - $0.availableHeadroom }
                )
            case .thermal:
                guard let thermal = adaptiveRingMonitor.performanceSnapshot?.thermalState else {
                    return "Thermal —"
                }
                switch thermal {
                case .nominal: return "Thermal · Nominal"
                case .fair: return "Thermal · Fair"
                case .serious: return "Thermal · Serious"
                case .critical: return "Thermal · Critical"
                }
            case .wifi:
                return percentCaption("Wi-Fi", statusStore.status.network.signalStrength)
            }
        }
    }

    private func percentCaption(_ label: String, _ fraction: Double?) -> String {
        guard let fraction else { return "\(label) —" }
        return "\(label) \(Int((fraction * 100).rounded()))%"
    }

    private func acquireMonitor() {
        adaptiveRingMonitor.acquire(owner: monitorOwner)
        var presentation = adaptivePresentation
        presentation.synchronize(to: adaptiveRingMonitor.state)
        adaptivePresentation = presentation
    }

    /// Briefly names the mode just entered, so a click-cycle is never a
    /// guessing game. Rapid clicking restarts the clock: only the latest
    /// generation may clear the label.
    private func flashModeName(_ newMode: DesktopWidgetMode) {
        toastName = newMode.title
        toastGeneration += 1
        let generation = toastGeneration
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.25))
            if toastGeneration == generation {
                toastName = nil
            }
        }
    }
}

/// Blur + fade pair for the mode-change transition: the outgoing face
/// blurs away while the incoming one sharpens from the same blur.
private struct WidgetModeBlurModifier: ViewModifier {
    let radius: CGFloat
    let opacity: Double

    func body(content: Content) -> some View {
        content
            .blur(radius: radius)
            .opacity(opacity)
    }
}
