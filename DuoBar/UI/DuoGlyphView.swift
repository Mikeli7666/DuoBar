import SwiftUI

struct DuoGlyphView: View {
    let status: SystemStatus
    var metrics: DuoGlyphMetrics = .standard
    var animationsEnabled = true
    var dotConfiguration: BluetoothDotConfiguration = .standard
    var style: DuoGlyphStyle = .classic
    var showPercentage = true
    var showAirplaneIndicator = true

    private var glyphState: DuoGlyphState {
        DuoGlyphState(status: status)
    }

    var body: some View {
        HStack(spacing: 2) {
            mainGlyph
            if glyphState.isCharging {
                Image(systemName: "bolt.fill")
                    .font(.system(size: metrics.overallSize * 0.44, weight: .bold))
                    .frame(width: metrics.chargingIndicatorWidth - 2)
                    .transition(.opacity)
            }
        }
        .foregroundStyle(.primary)
        .animation(layerAnimation, value: glyphState.isCharging)
        .accessibilityHidden(true)
    }

    private var mainGlyph: some View {
        ZStack {
            if style == .splitRing {
                splitRing
            } else {
                DuoArcShape(
                    startDegrees: metrics.arcStartDegrees,
                    endDegrees: metrics.arcEndDegrees,
                    progress: CGFloat(glyphState.batteryProgress)
                )
                .stroke(
                    style: StrokeStyle(
                        lineWidth: metrics.ringLineWidth,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
                .frame(width: metrics.ringDiameter, height: metrics.ringDiameter)
                .offset(y: metrics.ringYOffset)
                .foregroundStyle(status.battery.ringState.color)
                .opacity(glyphState.batteryArcOpacity)
                .animation(arcAnimation, value: glyphState.batteryProgress)
                .animation(layerAnimation, value: glyphState.batteryArcOpacity)

                centerGlyph
                .offset(y: metrics.wifiYOffset)

                curvedDots
            }
        }
        .frame(width: DuoGlyphMetrics.canvasSize, height: DuoGlyphMetrics.canvasSize)
        .offset(y: metrics.verticalCenteringOffset(style: style))
        .scaleEffect(metrics.overallSize / DuoGlyphMetrics.canvasSize)
        .frame(width: metrics.overallSize, height: metrics.overallSize)
        .foregroundStyle(.primary)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var centerGlyph: some View {
        if showAirplaneIndicator && status.areWirelessRadiosOff {
            Image(systemName: "airplane")
                .font(.system(size: metrics.wifiSymbolSize, weight: .semibold))
        } else {
            DuoCenterGlyph(signalLevel: glyphState.wifiLevel, size: metrics.wifiSymbolSize,
                           animationsEnabled: animationsEnabled)
        }
    }

    private var splitRing: some View {
        ZStack {
            if let percentage = splitRingPercentage {
                ForEach(0..<2) { side in
                    let start = side == 0 ? 145.0 : -45.0
                    let progress = min(max(glyphState.batteryProgress * 2 - Double(side), 0), 1)
                    batteryTrack(start: start, end: start + 80, progress: progress)
                }
                Text("\(percentage)")
                    .font(.system(size: percentage == 100 ? 7.5 : 8.5, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .frame(height: 10)
                    .offset(y: -11.5)
            } else {
                // With no label, join the two sides across the top. Keep the
                // dim track so an unfilled battery is distinct from a gap.
                batteryTrack(start: 145, end: 395, progress: glyphState.batteryProgress)
            }
            centerGlyph.offset(y: splitRingPercentage == nil ? metrics.wifiYOffset : 1)
            curvedDots
        }
    }

    private var splitRingPercentage: Int? {
        guard showPercentage, status.battery.isAvailable,
              let percentage = status.battery.percentage, (0...100).contains(percentage) else { return nil }
        return percentage
    }

    private func batteryTrack(start: Double, end: Double, progress: Double) -> some View {
        ZStack {
            DuoArcShape(startDegrees: start, endDegrees: end, progress: 1)
                .stroke(style: StrokeStyle(lineWidth: metrics.ringLineWidth, lineCap: .round))
                .opacity(0.18)
            DuoArcShape(startDegrees: start, endDegrees: end, progress: progress)
                .stroke(style: StrokeStyle(lineWidth: metrics.ringLineWidth, lineCap: .round))
                .foregroundStyle(status.battery.ringState.color)
                .opacity(glyphState.batteryArcOpacity)
                .animation(arcAnimation, value: progress)
        }
        .frame(width: metrics.ringDiameter, height: metrics.ringDiameter)
        .offset(y: metrics.ringYOffset)
    }

    private var curvedDots: some View {
        let dots = BluetoothDotPresentation(bluetooth: status.bluetooth, configuration: dotConfiguration).dots
        return ZStack {
            ForEach(dots.indices, id: \.self) { index in
                let position = metrics.dotPosition(at: index)
                DuoDotRow(dots: [dots[index]], diameter: metrics.dotDiameter,
                          spacing: 0, animationsEnabled: animationsEnabled)
                    .offset(x: position.x, y: position.y)
            }
        }
    }

    private var arcAnimation: Animation? {
        animationsEnabled ? .easeInOut(duration: 0.32) : nil
    }

    private var layerAnimation: Animation? {
        animationsEnabled ? AnimationConstants.content : nil
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
        let clampedProgress = min(max(progress, 0), 1)
        return startDegrees + (endDegrees - startDegrees) * Double(clampedProgress)
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
    let signalLevel: WiFiSignalLevel
    let size: CGFloat
    let animationsEnabled: Bool

    var body: some View {
        Image(systemName: symbolName, variableValue: signalLevel.symbolVariableValue)
            .font(.system(size: size, weight: .semibold))
            .symbolRenderingMode(.monochrome)
            .opacity(symbolOpacity)
            .id(signalLevel)
            .transition(.opacity.combined(with: .scale(scale: 0.82)))
            .frame(width: size * 1.55, height: size * 1.35)
            .animation(animationsEnabled ? AnimationConstants.content : nil, value: signalLevel)
    }

    private var symbolName: String {
        switch signalLevel {
        case .strong, .medium, .weak:
            "wifi"
        case .disconnected, .disabled, .unavailable:
            "wifi.slash"
        }
    }

    private var symbolOpacity: Double {
        signalLevel == .unavailable ? 0.35 : 1
    }
}

struct DuoDotRow: View {
    let dots: [BluetoothDotPresentation.Dot]
    let diameter: CGFloat
    let spacing: CGFloat
    let animationsEnabled: Bool

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(dots.indices, id: \.self) { index in
                Group {
                    if dots[index].isHollow {
                        Circle().strokeBorder(lineWidth: max(0.6, diameter * 0.25))
                    } else {
                        Circle()
                    }
                }
                    .frame(width: diameter, height: diameter)
                    .opacity(dots[index].opacity)
            }
        }
        .animation(animationsEnabled ? AnimationConstants.content : nil, value: dots)
    }
}
