#if DEBUG
import SwiftUI

struct DebugDuoGlyphTuningView: View {
    @AppStorage(DuoGlyphTuningKeys.overallSize) private var overallSize = Double(DuoGlyphMetrics.standard.overallSize)
    @AppStorage(DuoGlyphTuningKeys.ringDiameter) private var ringDiameter = Double(DuoGlyphMetrics.standard.ringDiameter)
    @AppStorage(DuoGlyphTuningKeys.ringLineWidth) private var ringLineWidth = Double(DuoGlyphMetrics.standard.ringLineWidth)
    @AppStorage(DuoGlyphTuningKeys.arcGap) private var arcGap = DuoGlyphMetrics.standard.arcGap
    @AppStorage(DuoGlyphTuningKeys.wifiSymbolSize) private var wifiSymbolSize = Double(DuoGlyphMetrics.standard.wifiSymbolSize)
    @AppStorage(DuoGlyphTuningKeys.wifiYOffset) private var wifiYOffset = Double(DuoGlyphMetrics.standard.wifiYOffset)
    @AppStorage(DuoGlyphTuningKeys.dotDiameter) private var dotDiameter = Double(DuoGlyphMetrics.standard.dotDiameter)
    @AppStorage(DuoGlyphTuningKeys.dotSpacing) private var dotSpacing = Double(DuoGlyphMetrics.standard.dotSpacing)
    @AppStorage(DuoGlyphTuningKeys.dotYOffset) private var dotYOffset = Double(DuoGlyphMetrics.standard.dotYOffset)

    var body: some View {
        Section("Duo Glyph Tuning · Debug") {
            DebugMetricSlider(title: "Overall size", value: $overallSize, range: 18...26, step: 0.25)
            DebugMetricSlider(title: "Ring diameter", value: $ringDiameter, range: 22...30, step: 0.25)
            DebugMetricSlider(title: "Ring thickness", value: $ringLineWidth, range: 1.5...4, step: 0.1)
            DebugMetricSlider(title: "Arc gap", value: $arcGap, range: 70...140, step: 1)
            DebugMetricSlider(title: "Wi-Fi size", value: $wifiSymbolSize, range: 8...15, step: 0.25)
            DebugMetricSlider(title: "Wi-Fi vertical", value: $wifiYOffset, range: -4...3, step: 0.1)
            DebugMetricSlider(title: "Dot diameter", value: $dotDiameter, range: 1.5...4, step: 0.1)
            DebugMetricSlider(title: "Dot spacing", value: $dotSpacing, range: 0.5...5, step: 0.1)
            DebugMetricSlider(title: "Dot vertical", value: $dotYOffset, range: 7...14, step: 0.1)

            Button("Reset Reference Geometry", action: reset)
        }
    }

    private func reset() {
        let metrics = DuoGlyphMetrics.standard
        overallSize = Double(metrics.overallSize)
        ringDiameter = Double(metrics.ringDiameter)
        ringLineWidth = Double(metrics.ringLineWidth)
        arcGap = metrics.arcGap
        wifiSymbolSize = Double(metrics.wifiSymbolSize)
        wifiYOffset = Double(metrics.wifiYOffset)
        dotDiameter = Double(metrics.dotDiameter)
        dotSpacing = Double(metrics.dotSpacing)
        dotYOffset = Double(metrics.dotYOffset)
    }
}

private struct DebugMetricSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .frame(width: 92, alignment: .leading)
            Slider(value: $value, in: range, step: step)
            Text(value.formatted(.number.precision(.fractionLength(step < 1 ? 1 : 0))))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 34, alignment: .trailing)
        }
    }
}
#endif
