import AppKit
import SwiftUI

enum BatteryBoltPresentationConstants {
    static let opacity = BatteryChargingAnimationProfile.boltOpacity
    static let hiddenScale: CGFloat = 0
    static let entranceDuration = BatteryChargingAnimationProfile.boltEntranceDuration
    static let exitDuration = BatteryChargingAnimationProfile.exitDuration
}

enum DuoNativeVisualConstants {
    static let inactiveElementOpacity = 0.28
    static let unknownElementOpacity = 0.28
    static let chargingColorDelay = BatteryChargingAnimationProfile.colorDelay
    static let chargingColorTransitionDuration = BatteryChargingAnimationProfile.colorTransitionDuration
    static let chargingTrackOpacity = BatteryChargingAnimationProfile.inactiveTrackOpacity
}

struct DuoGlyphView: View {
    let status: SystemStatus
    var presentation: StatusPresentation = .normal
    var metrics: DuoGlyphMetrics = .standard
    var animationsEnabled = true
    var ringPresentation: DuoPersistentRingPresentation?
    var centerStateOverride: DuoCenterState?
    var ringTransitionAnimation: Animation?
    var usesCustomRingTransition = false
    var ringColorOverride: Color?
    var batteryColorCodingEnabled = false
    var chargingBoltProgressOverride: CGFloat?
    var chargingTrackProgressOverride: CGFloat?
    var chargingColorMixOverride: CGFloat?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var centerPulseScale: CGFloat = 1
    @State private var chargingBoltProgress: CGFloat
    @State private var chargingTrackProgress: CGFloat
    @State private var chargingColorMix: CGFloat

    init(
        status: SystemStatus,
        presentation: StatusPresentation = .normal,
        metrics: DuoGlyphMetrics = .standard,
        animationsEnabled: Bool = true,
        ringPresentation: DuoPersistentRingPresentation? = nil,
        centerStateOverride: DuoCenterState? = nil,
        ringTransitionAnimation: Animation? = nil,
        usesCustomRingTransition: Bool = false,
        ringColorOverride: Color? = nil,
        batteryColorCodingEnabled: Bool = false,
        chargingBoltProgressOverride: CGFloat? = nil,
        chargingTrackProgressOverride: CGFloat? = nil,
        chargingColorMixOverride: CGFloat? = nil
    ) {
        self.status = status
        self.presentation = presentation
        self.metrics = metrics
        self.animationsEnabled = animationsEnabled
        self.ringPresentation = ringPresentation
        self.centerStateOverride = centerStateOverride
        self.ringTransitionAnimation = ringTransitionAnimation
        self.usesCustomRingTransition = usesCustomRingTransition
        self.ringColorOverride = ringColorOverride
        self.batteryColorCodingEnabled = batteryColorCodingEnabled
        self.chargingBoltProgressOverride = chargingBoltProgressOverride
        self.chargingTrackProgressOverride = chargingTrackProgressOverride
        self.chargingColorMixOverride = chargingColorMixOverride

        let state = DuoGlyphState(
            status: status,
            presentation: presentation,
            ringPresentation: ringPresentation,
            centerStateOverride: centerStateOverride,
            batteryColorCodingEnabled: batteryColorCodingEnabled
        )
        let usesPowerPresentation = state.batteryPresentation.boltPlacement != .none
        _chargingBoltProgress = State(initialValue: usesPowerPresentation ? 1 : 0)
        _chargingTrackProgress = State(initialValue: usesPowerPresentation ? 1 : 0)
        _chargingColorMix = State(initialValue: state.batteryPresentation.colorRole == .charging ? 1 : 0)
    }

    private var glyphState: DuoGlyphState {
        DuoGlyphState(
            status: status,
            presentation: presentation,
            ringPresentation: ringPresentation,
            centerStateOverride: centerStateOverride,
            batteryColorCodingEnabled: batteryColorCodingEnabled
        )
    }

    var body: some View {
        ZStack {
            Group {
                if glyphState.ringPresentation.mode == .adaptive {
                    GlyphArc(
                        startDegrees: metrics.arcStartDegrees,
                        endDegrees: metrics.arcEndDegrees,
                        progress: CGFloat(glyphState.batteryProgress),
                        lineWidth: metrics.arcLineWidth,
                        diameter: metrics.ringPathDiameter,
                        yOffset: metrics.ringYOffset,
                        swiftColor: ringColorOverride ?? .primary,
                        solidColor: adaptiveSolidColor,
                        opacity: glyphState.batteryArcOpacity
                    )
                    .animation(arcAnimation, value: glyphState.batteryProgress)
                    .animation(arcOpacityAnimation, value: glyphState.batteryArcOpacity)
                    .transition(.opacity)
                } else {
                    ZStack {
                        GlyphArc(
                            startDegrees: metrics.arcStartDegrees,
                            endDegrees: metrics.arcEndDegrees,
                            progress: 1,
                            lineWidth: metrics.arcLineWidth,
                            diameter: metrics.ringPathDiameter,
                            yOffset: metrics.ringYOffset,
                            swiftColor: batteryArcColor,
                            solidColor: solidBatteryColor,
                            opacity: glyphState.batteryArcOpacity
                                * DuoNativeVisualConstants.chargingTrackOpacity
                                * Double(chargingTrackProgressOverride ?? chargingTrackProgress)
                        )

                        GlyphArc(
                            startDegrees: metrics.arcStartDegrees,
                            endDegrees: metrics.arcEndDegrees,
                            progress: CGFloat(glyphState.batteryProgress),
                            lineWidth: metrics.arcLineWidth,
                            diameter: metrics.ringPathDiameter,
                            yOffset: metrics.ringYOffset,
                            swiftColor: batteryArcColor,
                            solidColor: solidBatteryColor,
                            opacity: glyphState.batteryArcOpacity
                        )
                        .animation(arcAnimation, value: glyphState.batteryProgress)
                        .animation(arcOpacityAnimation, value: glyphState.batteryArcOpacity)

                        DuoChargingBolt(
                            progress: chargingBoltProgressOverride ?? chargingBoltProgress,
                            size: chargingBoltSize,
                            offset: chargingBoltOffset,
                            color: .primary,
                            opacity: chargingBoltOpacity
                        )
                    }
                    .frame(width: DuoGlyphMetrics.canvasSize, height: DuoGlyphMetrics.canvasSize)
                    .transition(.opacity)
                }
            }
            .animation(ringModeTransitionAnimation, value: glyphState.ringPresentation.mode)

            DuoCenterTransitionView(
                targetState: glyphState.centerState,
                size: metrics.wifiSymbolSize,
                ringDiameter: metrics.ringDiameter,
                ringYOffset: metrics.ringYOffset,
                centerYOffset: metrics.wifiYOffset,
                pulseScale: centerPulseScale,
                animationsEnabled: animationsEnabled,
                reduceMotion: reduceMotion,
                sourceTint: adaptiveSourceTint
            )
            .offset(y: metrics.wifiYOffset)

            DuoDotRow(
                activeCount: glyphState.volumeActiveDotCount,
                diameter: metrics.dotDiameter,
                ringDiameter: metrics.ringDiameter,
                rowCenterYOffset: metrics.dotYOffset,
                animationsEnabled: motionAllowed
            )
        }
        .frame(width: DuoGlyphMetrics.canvasSize, height: DuoGlyphMetrics.canvasSize)
        .scaleEffect(metrics.overallSize / DuoGlyphMetrics.canvasSize)
        .frame(width: metrics.overallSize, height: metrics.overallSize)
        .accessibilityHidden(true)
        .task(id: glyphState.audioEventID) {
            $centerPulseScale.wrappedValue = 1
            guard glyphState.audioEventID != nil, motionAllowed else { return }
            try? await Task.sleep(for: .milliseconds(260))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.1)) {
                $centerPulseScale.wrappedValue = 1.055
            }
            try? await Task.sleep(for: .milliseconds(100))
            guard !Task.isCancelled else {
                $centerPulseScale.wrappedValue = 1
                return
            }
            withAnimation(.spring(response: 0.24, dampingFraction: 0.9)) {
                $centerPulseScale.wrappedValue = 1
            }
        }
        .onChange(of: chargingPresentationTarget) { target in
            let showing = target > 0
            if chargingBoltProgressOverride == nil {
                withAnimation(boltAnimation(showing: showing)) {
                    $chargingBoltProgress.wrappedValue = target
                }
            }
            if chargingTrackProgressOverride == nil {
                withAnimation(trackAnimation(showing: showing)) {
                    $chargingTrackProgress.wrappedValue = target
                }
            }
        }
        .task(id: chargingColorTarget) {
            guard chargingColorMixOverride == nil else { return }
            guard chargingColorMix != chargingColorTarget else { return }
            guard motionAllowed else {
                $chargingColorMix.wrappedValue = chargingColorTarget
                return
            }

            if chargingColorTarget > 0 {
                try? await Task.sleep(for: .seconds(DuoNativeVisualConstants.chargingColorDelay))
                guard !Task.isCancelled else { return }
            }
            withAnimation(chargingColorAnimation(showing: chargingColorTarget > 0)) {
                $chargingColorMix.wrappedValue = chargingColorTarget
            }
        }
        #if DEBUG
        .onChange(of: glyphState.centerState) { centerState in
            if centerState == .adaptiveEntry {
                NSLog("%@", "[DuoBar Adaptive QA] sparkles displayed")
            }
        }
        #endif
    }

    private var adaptiveSourceTint: Color? {
        switch glyphState.centerState {
        case .adaptiveBrightness, .performanceCPU, .performanceMemory, .performanceThermal:
            return ringColorOverride
        default:
            return nil
        }
    }

    private var motionAllowed: Bool {
        animationsEnabled && !reduceMotion
    }

    private var ringStrokeStyle: StrokeStyle {
        StrokeStyle(
            lineWidth: metrics.arcLineWidth,
            lineCap: .round,
            lineJoin: .round
        )
    }

    /// Real color for the arc. Nil keeps the menu-bar template tint, so the arc stays white or black with the other icons.
    private var adaptiveSolidColor: NSColor? {
        guard let ringColorOverride else { return nil }
        return NSColor(ringColorOverride)
    }

    private var solidBatteryColor: NSColor? {
        if effectiveChargingColorMix > 0 {
            let base = nsColor(for: nonChargingBatteryColorRole)
            return base.blended(withFraction: effectiveChargingColorMix, of: .systemGreen) ?? .systemGreen
        }
        switch BatteryRingPresentation.resolve(battery: status.battery, colorCodingEnabled: batteryColorCodingEnabled).colorRole {
        case .charging: return nsColor(for: nonChargingBatteryColorRole)
        case .lowPowerMode: return .systemYellow
        case .lowBattery: return .systemRed
        case .monochrome: return nil
        }
    }

    private var batteryArcColor: Color {
        if effectiveChargingColorMix > 0 {
            let base = nsColor(for: nonChargingBatteryColorRole)
            let mixed = base.blended(
                withFraction: effectiveChargingColorMix,
                of: .systemGreen
            ) ?? .systemGreen
            return Color(nsColor: mixed)
        }

        switch BatteryRingPresentation.resolve(battery: status.battery, colorCodingEnabled: batteryColorCodingEnabled).colorRole {
        case .charging: return Color(nsColor: nsColor(for: nonChargingBatteryColorRole))
        case .lowPowerMode: return Color(nsColor: .systemYellow)
        case .lowBattery: return Color(nsColor: .systemRed)
        case .monochrome: break
        }

        switch glyphState.feedback {
        case .charging, .lowBattery: return .primary
        case .none, .audioConnected: return ringColorOverride ?? .primary
        }
    }

    private var arcAnimation: Animation? {
        guard motionAllowed else { return nil }
        if usesCustomRingTransition { return ringTransitionAnimation }
        return layerAnimation
    }

    private var arcOpacityAnimation: Animation? {
        guard motionAllowed else { return nil }
        return usesCustomRingTransition ? ringTransitionAnimation : layerAnimation
    }

    private var layerAnimation: Animation? {
        motionAllowed ? AnimationConstants.content : nil
    }

    private var ringModeTransitionAnimation: Animation? {
        motionAllowed ? .easeInOut(duration: 0.32) : nil
    }

    private var chargingBoltOffset: CGSize {
        let point = DuoRingGeometry.chargingBoltPoint(metrics: metrics)
        return CGSize(
            width: point.x,
            height: point.y
        )
    }

    private var chargingBoltSize: CGFloat {
        metrics.ringDiameter * BatteryChargingAnimationProfile.boltFontSizeRatio
    }

    private var chargingBoltOpacity: Double {
        BatteryBoltPresentationConstants.opacity
    }

    private var chargingPresentationTarget: CGFloat {
        glyphState.batteryPresentation.boltPlacement == .none ? 0 : 1
    }

    private var chargingColorTarget: CGFloat {
        glyphState.batteryPresentation.colorRole == .charging ? 1 : 0
    }

    private var effectiveChargingColorMix: CGFloat {
        chargingColorMixOverride ?? chargingColorMix
    }

    private var nonChargingBatteryColorRole: BatteryRingColorRole {
        guard batteryColorCodingEnabled else { return .monochrome }
        let battery = status.battery
        if battery.isPluggedIn { return .monochrome }
        if battery.isLowPowerModeEnabled { return .lowPowerMode }
        if let percentage = battery.percentage, percentage < 20 { return .lowBattery }
        return .monochrome
    }

    private func nsColor(for role: BatteryRingColorRole) -> NSColor {
        switch role {
        case .charging: return .systemGreen
        case .lowPowerMode: return .systemYellow
        case .lowBattery: return .systemRed
        case .monochrome: return .labelColor
        }
    }

    private func boltAnimation(showing: Bool) -> Animation? {
        guard motionAllowed else { return nil }
        if showing {
            return .timingCurve(
                0.33, 1, 0.68, 1,
                duration: BatteryBoltPresentationConstants.entranceDuration
            )
        }
        return .timingCurve(0.4, 0, 0.2, 1, duration: BatteryBoltPresentationConstants.exitDuration)
    }

    private func trackAnimation(showing: Bool) -> Animation? {
        guard motionAllowed else { return nil }
        let duration = showing
            ? BatteryChargingAnimationProfile.trackEntranceDuration
            : BatteryChargingAnimationProfile.exitDuration
        return .timingCurve(0.4, 0, 0.2, 1, duration: duration)
    }

    private func chargingColorAnimation(showing: Bool) -> Animation? {
        guard motionAllowed else { return nil }
        let duration = showing
            ? DuoNativeVisualConstants.chargingColorTransitionDuration
            : BatteryChargingAnimationProfile.exitDuration
        if showing {
            return .timingCurve(0.33, 1, 0.68, 1, duration: duration)
        }
        return .timingCurve(0.4, 0, 0.2, 1, duration: duration)
    }
}

enum DuoRingGeometry {
    static func endDegrees(startDegrees: Double, endDegrees: Double, progress: Double) -> Double {
        let clampedProgress = min(max(progress, 0), 1)
        return startDegrees + (endDegrees - startDegrees) * clampedProgress
    }

    static func endpoint(
        metrics: DuoGlyphMetrics,
        progress: Double,
        radialOffset: CGFloat = 0
    ) -> CGPoint {
        let degrees = endDegrees(
            startDegrees: metrics.arcStartDegrees,
            endDegrees: metrics.arcEndDegrees,
            progress: progress
        )
        let radians = degrees * .pi / 180
        let radius = metrics.ringPathDiameter / 2 + radialOffset
        return CGPoint(
            x: CGFloat(cos(radians)) * radius,
            y: CGFloat(sin(radians)) * radius + metrics.ringYOffset
        )
    }

    static func midpoint(metrics: DuoGlyphMetrics, radialOffset: CGFloat = 0) -> CGPoint {
        endpoint(metrics: metrics, progress: 0.5, radialOffset: radialOffset)
    }

    static func chargingBoltPoint(metrics: DuoGlyphMetrics) -> CGPoint {
        let point = midpoint(
            metrics: metrics,
            radialOffset: metrics.ringDiameter * BatteryChargingAnimationProfile.boltRadialOffsetRatio
        )
        return CGPoint(
            x: point.x + metrics.ringDiameter * BatteryChargingAnimationProfile.boltHorizontalOffsetRatio,
            y: point.y
        )
    }
}

struct DuoCenterTransitionView: View {
    let targetState: DuoCenterState
    let size: CGFloat
    let ringDiameter: CGFloat
    let ringYOffset: CGFloat
    let centerYOffset: CGFloat
    let pulseScale: CGFloat
    let animationsEnabled: Bool
    let reduceMotion: Bool
    var sourceTint: Color? = nil

    @State private var displayedState: DuoCenterState
    @State private var outgoingState: DuoCenterState?
    @State private var transitionProgress: CGFloat = 1

    init(
        targetState: DuoCenterState,
        size: CGFloat,
        ringDiameter: CGFloat,
        ringYOffset: CGFloat,
        centerYOffset: CGFloat,
        pulseScale: CGFloat,
        animationsEnabled: Bool,
        reduceMotion: Bool,
        sourceTint: Color? = nil
    ) {
        self.targetState = targetState
        self.size = size
        self.ringDiameter = ringDiameter
        self.ringYOffset = ringYOffset
        self.centerYOffset = centerYOffset
        self.pulseScale = pulseScale
        self.animationsEnabled = animationsEnabled
        self.reduceMotion = reduceMotion
        self.sourceTint = sourceTint
        _displayedState = State(initialValue: targetState)
    }

    var body: some View {
        DuoCenterTransitionLayer(
            outgoingState: outgoingState,
            incomingState: displayedState,
            progress: transitionProgress,
            sourceTint: sourceTint,
            pulseScale: pulseScale,
            size: size,
            ringDiameter: ringDiameter,
            wifiVerticalAdjustment: DuoWiFiReferenceGeometry.verticalAdjustment(
                ringDiameter: ringDiameter,
                ringYOffset: ringYOffset,
                centerYOffset: centerYOffset
            ),
            usesSpatialMotion: !reduceMotion
        )
        .onChange(of: targetState) { newState in
            transition(to: newState)
        }
        .task(id: targetState) {
            try? await Task.sleep(for: .milliseconds(270))
            guard !Task.isCancelled else { return }
            $outgoingState.wrappedValue = nil
        }
    }

    private func transition(to newState: DuoCenterState) {
        guard newState != displayedState else { return }
        guard animationsEnabled else {
            $outgoingState.wrappedValue = nil
            $displayedState.wrappedValue = newState
            $transitionProgress.wrappedValue = 1
            return
        }

        $outgoingState.wrappedValue = displayedState
        $displayedState.wrappedValue = newState
        $transitionProgress.wrappedValue = 0
        withAnimation(.easeInOut(duration: 0.25)) {
            $transitionProgress.wrappedValue = 1
        }
    }
}

struct DuoCenterTransitionLayer: View {
    let outgoingState: DuoCenterState?
    let incomingState: DuoCenterState
    let progress: CGFloat
    var sourceTint: Color? = nil
    let pulseScale: CGFloat
    let size: CGFloat
    let ringDiameter: CGFloat
    let wifiVerticalAdjustment: CGFloat
    let usesSpatialMotion: Bool

    init(
        outgoingState: DuoCenterState?,
        incomingState: DuoCenterState,
        progress: CGFloat,
        sourceTint: Color? = nil,
        pulseScale: CGFloat,
        size: CGFloat,
        ringDiameter: CGFloat = DuoGlyphMetrics.standard.ringDiameter,
        wifiVerticalAdjustment: CGFloat = DuoWiFiReferenceGeometry.verticalAdjustment(
            ringDiameter: DuoGlyphMetrics.standard.ringDiameter,
            ringYOffset: DuoGlyphMetrics.standard.ringYOffset,
            centerYOffset: DuoGlyphMetrics.standard.wifiYOffset
        ),
        usesSpatialMotion: Bool
    ) {
        self.outgoingState = outgoingState
        self.incomingState = incomingState
        self.progress = progress
        self.sourceTint = sourceTint
        self.pulseScale = pulseScale
        self.size = size
        self.ringDiameter = ringDiameter
        self.wifiVerticalAdjustment = wifiVerticalAdjustment
        self.usesSpatialMotion = usesSpatialMotion
    }

    var body: some View {
        ZStack {
            if let outgoingState {
                DuoCenterGlyph(
                    state: outgoingState,
                    size: size,
                    ringDiameter: ringDiameter,
                    wifiVerticalAdjustment: wifiVerticalAdjustment,
                    sourceTint: sourceTint
                )
                    .opacity(1 - progress)
                    .scaleEffect(usesSpatialMotion ? 1 - (0.1 * progress) : 1)
                    .offset(
                        x: usesSpatialMotion ? -travelDistance * progress : 0,
                        y: usesSpatialMotion ? -travelDistance * progress : 0
                    )
            }

            DuoCenterGlyph(
                state: incomingState,
                size: size,
                ringDiameter: ringDiameter,
                wifiVerticalAdjustment: wifiVerticalAdjustment,
                sourceTint: sourceTint
            )
                .opacity(progress)
                .scaleEffect((usesSpatialMotion ? 0.9 + (0.1 * progress) : 1) * incomingPulseScale)
                .offset(
                    x: usesSpatialMotion ? travelDistance * (1 - progress) : 0,
                    y: usesSpatialMotion ? travelDistance * (1 - progress) : 0
                )
        }
        .frame(width: size * 1.65, height: size * 1.4)
    }

    private var incomingPulseScale: CGFloat {
        incomingState.isTemporaryAudioState ? pulseScale : 1
    }

    // The standard glyph is scaled from a 32 pt design canvas to 24 pt in the menu bar.
    // This produces an effective two-point displacement at the installed size.
    private var travelDistance: CGFloat {
        size * 0.215
    }
}

/// Draws one arc. A real NSColor is painted outside menu-bar vibrancy so yellow, blue, and red stay colored. A nil color uses the template tint.
private struct GlyphArc: View {
    let startDegrees: Double
    let endDegrees: Double
    let progress: CGFloat
    let lineWidth: CGFloat
    let diameter: CGFloat
    let yOffset: CGFloat
    let swiftColor: Color
    let solidColor: NSColor?
    let opacity: Double

    var body: some View {
        Group {
            if let solidColor {
                MenuBarSolidArc(
                    startDegrees: startDegrees,
                    endDegrees: endDegrees,
                    progress: progress,
                    lineWidth: lineWidth,
                    color: solidColor,
                    opacity: opacity
                )
            } else {
                DuoArcShape(
                    startDegrees: startDegrees,
                    endDegrees: endDegrees,
                    progress: progress
                )
                .stroke(
                    swiftColor,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                )
                .opacity(opacity)
            }
        }
        .frame(width: diameter, height: diameter)
        .offset(y: yOffset)
    }
}

/// Menu-bar vibrancy turns ordinary SwiftUI color into the template tint. This view opts out, so a colored arc stays colored while the Wi-Fi mark and volume dots remain white or black with the rest of the menu bar.
private struct MenuBarSolidArc: NSViewRepresentable {
    var startDegrees: Double
    var endDegrees: Double
    var progress: CGFloat
    var lineWidth: CGFloat
    var color: NSColor
    var opacity: Double

    func makeNSView(context: Context) -> MenuBarSolidArcView {
        let view = MenuBarSolidArcView()
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.defaultLow, for: .vertical)
        return view
    }

    func updateNSView(_ view: MenuBarSolidArcView, context: Context) {
        view.startDegrees = startDegrees
        view.endDegrees = endDegrees
        view.progress = progress
        view.lineWidth = lineWidth
        view.strokeColor = color
        view.strokeOpacity = opacity
        view.needsDisplay = true
    }
}

private final class MenuBarSolidArcView: NSView {
    var startDegrees: Double = 0
    var endDegrees: Double = 0
    var progress: CGFloat = 0
    var lineWidth: CGFloat = 2
    var strokeColor: NSColor = .systemYellow
    var strokeOpacity: Double = 1

    override var allowsVibrancy: Bool { false }
    override var isOpaque: Bool { false }
    override var isFlipped: Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func draw(_ dirtyRect: NSRect) {
        let clamped = min(max(progress, 0), 1)
        guard clamped > 0, bounds.width > 0, bounds.height > 0 else { return }

        let visibleEnd = DuoRingGeometry.endDegrees(
            startDegrees: startDegrees,
            endDegrees: endDegrees,
            progress: Double(clamped)
        )
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = min(bounds.width, bounds.height) / 2
        let sampleCount = 72
        let path = NSBezierPath()
        path.lineWidth = lineWidth
        path.lineCapStyle = .round
        path.lineJoinStyle = .round

        for index in 0...sampleCount {
            let sampleProgress = Double(index) / Double(sampleCount)
            let degrees = startDegrees + (visibleEnd - startDegrees) * sampleProgress
            let radians = degrees * .pi / 180
            let point = CGPoint(
                x: center.x + CGFloat(cos(radians)) * radius,
                y: center.y + CGFloat(sin(radians)) * radius
            )
            if index == 0 {
                path.move(to: point)
            } else {
                path.line(to: point)
            }
        }

        strokeColor.withAlphaComponent(strokeOpacity).setStroke()
        path.stroke()
    }
}

struct DuoArcShape: Shape {
    let startDegrees: Double
    let endDegrees: Double
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    var visibleEndDegrees: Double {
        DuoRingGeometry.endDegrees(
            startDegrees: startDegrees,
            endDegrees: endDegrees,
            progress: Double(progress)
        )
    }

    func path(in rect: CGRect) -> Path {
        let clampedProgress = min(max(progress, 0), 1)
        guard clampedProgress > 0 else { return Path() }

        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let sampleCount = 72

        var path = Path()
        for index in 0...sampleCount {
            let sampleProgress = Double(index) / Double(sampleCount)
            let degrees = startDegrees + (visibleEndDegrees - startDegrees) * sampleProgress
            let radians = degrees * .pi / 180
            let point = CGPoint(
                x: center.x + CGFloat(cos(radians)) * radius,
                y: center.y + CGFloat(sin(radians)) * radius
            )

            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        return path
    }
}

struct DuoCenterGlyph: View {
    let state: DuoCenterState
    let size: CGFloat
    let ringDiameter: CGFloat
    let wifiVerticalAdjustment: CGFloat
    var sourceTint: Color? = nil

    var body: some View {
        Group {
            if case let .wifi(level) = state {
                DuoWiFiGlyph(
                    level: level,
                    ringDiameter: ringDiameter,
                    verticalAdjustment: wifiVerticalAdjustment
                )
            } else {
                Image(systemName: Self.symbolName(for: state))
                    .font(.system(size: symbolSize, weight: .semibold))
                    .symbolRenderingMode(.monochrome)
            }
        }
        .foregroundStyle(glyphColor)
        .opacity(symbolOpacity)
        .frame(width: size * 1.65, height: size * 1.4)
    }

    static func symbolName(for state: DuoCenterState) -> String {
        switch state {
        case .wifi: "wifi"
        case .ethernet: "cable.connector.horizontal"
        case .offline: "network.slash"
        case .other: "ellipsis.circle"
        case .unavailable: "network.slash"
        case .airPodsPro: "airpodspro"
        case .airPodsMax: "airpodsmax"
        case .airPods: "airpods"
        case .headphones: "headphones"
        case .audioDevice: "speaker.wave.2"
        case .adaptiveBrightness: "sun.max.fill"
        case .performanceCPU: "cpu"
        case .performanceMemory: "memorychip"
        case .performanceThermal: "thermometer.medium"
        case .adaptiveEntry: "sparkles"
        }
    }

    private var symbolSize: CGFloat {
        switch state {
        case .ethernet, .other, .airPodsPro, .airPodsMax, .airPods, .headphones, .audioDevice,
             .adaptiveBrightness, .performanceCPU, .performanceMemory, .performanceThermal, .adaptiveEntry:
            size * 0.92
        case .wifi, .offline, .unavailable: size
        }
    }

    private var symbolOpacity: Double {
        state == .unavailable ? 0.34 : 1
    }

    private var glyphColor: Color {
        if state.isTemporaryAudioState { return .accentColor.opacity(0.86) }
        if let sourceTint, state.usesAdaptiveSourceColor { return sourceTint }
        return .primary
    }
}

enum DuoWiFiVisualStyle {
    enum Band: Int, CaseIterable {
        case core
        case middle
        case outer
    }

    static func opacity(for band: Band, level: WiFiSignalLevel) -> Double {
        let activeBandCount: Int
        switch level {
        case .strong: activeBandCount = 3
        case .medium: activeBandCount = 2
        case .weak: activeBandCount = 1
        case .disconnected, .disabled, .unavailable: activeBandCount = 0
        }
        return band.rawValue < activeBandCount ? 1 : DuoNativeVisualConstants.inactiveElementOpacity
    }
}

enum DuoWiFiReferenceGeometry {
    // Measurements from the unobscured strong-Wi-Fi frame at 27.00 seconds.
    // All production geometry is normalized to the 230 px reference outer-ring diameter.
    static let referenceRingDiameter: CGFloat = 230
    static let totalWidthRatio: CGFloat = 100 / referenceRingDiameter
    static let totalHeightRatio: CGFloat = 73 / referenceRingDiameter
    static let outerArcWidthRatio: CGFloat = 100 / referenceRingDiameter
    static let outerArcHeightRatio: CGFloat = 31 / referenceRingDiameter
    static let innerArcWidthRatio: CGFloat = 64 / referenceRingDiameter
    static let innerArcHeightRatio: CGFloat = 23 / referenceRingDiameter
    static let strokeWidthRatio: CGFloat = 14.5 / referenceRingDiameter
    static let referenceRingStrokeRatio: CGFloat = 18 / referenceRingDiameter
    static let coreWidthRatio: CGFloat = 29 / referenceRingDiameter
    static let coreHeightRatio: CGFloat = 21 / referenceRingDiameter
    static let outerToInnerCenterGapRatio: CGFloat = 11 / referenceRingDiameter
    static let innerToCoreCenterGapRatio: CGFloat = 12 / referenceRingDiameter
    static let opticalCenterYOffsetRatio: CGFloat = -15 / referenceRingDiameter

    static func verticalAdjustment(
        ringDiameter: CGFloat,
        ringYOffset: CGFloat,
        centerYOffset: CGFloat
    ) -> CGFloat {
        ringYOffset + ringDiameter * opticalCenterYOffsetRatio - centerYOffset
    }
}

struct DuoWiFiGlyph: View {
    let level: WiFiSignalLevel
    let ringDiameter: CGFloat
    let verticalAdjustment: CGFloat

    var body: some View {
        let width = ringDiameter * DuoWiFiReferenceGeometry.totalWidthRatio
        let height = ringDiameter * DuoWiFiReferenceGeometry.totalHeightRatio
        let lineWidth = ringDiameter * DuoWiFiReferenceGeometry.strokeWidthRatio
        ZStack {
            DuoWiFiArcShape(kind: .outer)
                .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                .opacity(DuoWiFiVisualStyle.opacity(for: .outer, level: level))
            DuoWiFiArcShape(kind: .middle)
                .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                .opacity(DuoWiFiVisualStyle.opacity(for: .middle, level: level))
            DuoWiFiCoreShape()
                .fill()
                .opacity(DuoWiFiVisualStyle.opacity(for: .core, level: level))
        }
        .frame(width: width, height: height)
        .offset(y: verticalAdjustment)
    }
}

private struct DuoWiFiArcShape: Shape {
    enum Kind {
        case outer
        case middle
    }

    let kind: Kind

    func path(in rect: CGRect) -> Path {
        var path = Path()
        switch kind {
        case .outer:
            path.move(to: CGPoint(x: rect.width * 0.075, y: rect.height * 0.321918))
            path.addQuadCurve(
                to: CGPoint(x: rect.width * 0.915, y: rect.height * 0.321918),
                control: CGPoint(x: rect.width * 0.495, y: rect.height * -0.130137)
            )
        case .middle:
            path.move(to: CGPoint(x: rect.width * 0.25, y: rect.height * 0.568493))
            path.addQuadCurve(
                to: CGPoint(x: rect.width * 0.74, y: rect.height * 0.568493),
                control: CGPoint(x: rect.width * 0.495, y: rect.height * 0.321918)
            )
        }
        return path
    }
}

private struct DuoWiFiCoreShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width * 0.365, y: rect.height * 0.815068))
        path.addQuadCurve(
            to: CGPoint(x: rect.width * 0.635, y: rect.height * 0.815068),
            control: CGPoint(x: rect.width * 0.5, y: rect.height * 0.650685)
        )
        path.addCurve(
            to: CGPoint(x: rect.width * 0.5, y: rect.height * 0.993151),
            control1: CGPoint(x: rect.width * 0.635, y: rect.height * 0.883562),
            control2: CGPoint(x: rect.width * 0.555, y: rect.height * 0.993151)
        )
        path.addCurve(
            to: CGPoint(x: rect.width * 0.365, y: rect.height * 0.815068),
            control1: CGPoint(x: rect.width * 0.445, y: rect.height * 0.993151),
            control2: CGPoint(x: rect.width * 0.365, y: rect.height * 0.883562)
        )
        return path
    }
}

private extension DuoCenterState {
    var usesAdaptiveSourceColor: Bool {
        switch self {
        case .adaptiveBrightness, .performanceCPU, .performanceMemory, .performanceThermal: true
        default: false
        }
    }

    var isTemporaryAudioState: Bool {
        switch self {
        case .airPodsPro, .airPodsMax, .airPods, .headphones, .audioDevice: true
        case .wifi, .ethernet, .offline, .other, .unavailable,
             .adaptiveBrightness, .performanceCPU, .performanceMemory, .performanceThermal, .adaptiveEntry:
            false
        }
    }
}

struct DuoDotRow: View {
    let activeCount: Int?
    let diameter: CGFloat
    let ringDiameter: CGFloat
    let rowCenterYOffset: CGFloat
    let animationsEnabled: Bool

    var body: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { index in
                Circle()
                    .frame(width: diameter, height: diameter)
                    .opacity(opacity(for: index))
                    .offset(
                        x: ringDiameter * DuoVolumeIndicatorGeometry.centerXOffsets[index],
                        y: rowCenterYOffset
                            + ringDiameter * DuoVolumeIndicatorGeometry.centerYOffsets[index]
                    )
            }
        }
        .frame(width: ringDiameter, height: ringDiameter)
        .foregroundStyle(.primary)
        .animation(animationsEnabled ? AnimationConstants.content : nil, value: activeCount)
    }

    func opacity(for index: Int) -> Double {
        guard let activeCount else { return DuoVolumeIndicatorGeometry.unknownOpacity }
        return index < activeCount
            ? DuoVolumeIndicatorGeometry.activeOpacity
            : DuoVolumeIndicatorGeometry.inactiveOpacity
    }
}

enum DuoVolumeIndicatorGeometry {
    // Measurements from the stable all-active frame at 27.00 seconds,
    // normalized to the 230 px reference outer-ring diameter.
    static let referenceRingDiameter: CGFloat = 230
    static let indicatorDiameterRatio: CGFloat = 21.5 / referenceRingDiameter
    static let rowWidthRatio: CGFloat = 132 / referenceRingDiameter
    static let rowHeightRatio: CGFloat = 35 / referenceRingDiameter
    static let outerEdgeGapRatio: CGFloat = 14.25 / referenceRingDiameter
    static let innerEdgeGapRatio: CGFloat = 17.5 / referenceRingDiameter
    static let wifiToRowGapRatio: CGFloat = 33.25 / referenceRingDiameter
    static let rowToRingBottomGapRatio: CGFloat = 25.75 / referenceRingDiameter
    static let centerXOffsets: [CGFloat] = [-55.25, -19.5, 19.5, 55.25]
        .map { $0 / referenceRingDiameter }
    static let centerYOffsets: [CGFloat] = [-6.5, 6.5, 6.5, -6.5]
        .map { $0 / referenceRingDiameter }
    static let activeOpacity = 1.0
    static let inactiveOpacity = 0.30
    static let unknownOpacity = 0.30
}

private struct DuoChargingBolt: View {
    let progress: CGFloat
    let size: CGFloat
    let offset: CGSize
    let color: Color
    let opacity: Double

    var body: some View {
        Image(systemName: "bolt.fill")
            .font(.system(size: size, weight: .bold))
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(color)
            .offset(offset)
            .opacity(opacity * Double(progress))
            .scaleEffect(
                BatteryBoltPresentationConstants.hiddenScale
                    + (1 - BatteryBoltPresentationConstants.hiddenScale) * progress
            )
    }
}
