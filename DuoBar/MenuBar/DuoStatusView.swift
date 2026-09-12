import AppKit
import SwiftUI

struct DuoStatusView: View {
    @ObservedObject private var statusStore: SystemStatusStore
    @AppStorage(PreferenceKeys.animationsEnabled) private var animationsEnabled = true

    @AppStorage(PreferenceKeys.showMenuBarBatteryPercentage) private var showMenuBarBatteryPercentage = false
    private var dotPreferences = BluetoothDotPreferences()

    #if DEBUG
    @AppStorage(DuoGlyphTuningKeys.overallSize) private var overallSize = Double(DuoGlyphMetrics.standard.overallSize)
    @AppStorage(DuoGlyphTuningKeys.ringDiameter) private var ringDiameter = Double(DuoGlyphMetrics.standard.ringDiameter)
    @AppStorage(DuoGlyphTuningKeys.ringLineWidth) private var ringLineWidth = Double(DuoGlyphMetrics.standard.ringLineWidth)
    @AppStorage(DuoGlyphTuningKeys.arcGap) private var arcGap = DuoGlyphMetrics.standard.arcGap
    @AppStorage(DuoGlyphTuningKeys.wifiSymbolSize) private var wifiSymbolSize = Double(DuoGlyphMetrics.standard.wifiSymbolSize)
    @AppStorage(DuoGlyphTuningKeys.wifiYOffset) private var wifiYOffset = Double(DuoGlyphMetrics.standard.wifiYOffset)
    @AppStorage(DuoGlyphTuningKeys.dotDiameter) private var dotDiameter = Double(DuoGlyphMetrics.standard.dotDiameter)
    @AppStorage(DuoGlyphTuningKeys.dotSpacing) private var dotSpacing = Double(DuoGlyphMetrics.standard.dotSpacing)
    @AppStorage(DuoGlyphTuningKeys.dotYOffset) private var dotYOffset = Double(DuoGlyphMetrics.standard.dotYOffset)
    #endif

    private let onWidthChange: (CGFloat) -> Void

    init(statusStore: SystemStatusStore, onWidthChange: @escaping (CGFloat) -> Void = { _ in }) {
        self.statusStore = statusStore
        self.onWidthChange = onWidthChange
    }

    private var targetWidth: CGFloat {
        metrics.statusItemWidth
        + (DuoGlyphState(status: statusStore.status).isCharging ? metrics.chargingIndicatorWidth : 0)
        + (percentageText.map { text in
            ceil((text as NSString).size(withAttributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)]).width) + 5
        } ?? 0)
    }

    private var percentageText: String? {
        guard showMenuBarBatteryPercentage, statusStore.status.battery.isAvailable,
              let percentage = statusStore.status.battery.percentage else { return nil }
        return "\(percentage)%"
    }

    var body: some View {
        HStack(spacing: 5) {
            DuoGlyphView(
                status: statusStore.status,
                metrics: metrics,
                animationsEnabled: animationsEnabled,
                dotConfiguration: dotPreferences.configuration
            )
            if let percentageText {
                Text(percentageText)
                    .font(.system(size: 12))
                    .monospacedDigit()
                    .fixedSize()
            }
        }
        .frame(width: targetWidth, height: NSStatusBar.system.thickness)
        .contentShape(Rectangle())
        .onAppear { onWidthChange(targetWidth) }
        .onChange(of: targetWidth) { _, newValue in onWidthChange(newValue) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        let wifi = statusStore.status.wifi.isConnected ? "Wi-Fi connected" : "Wi-Fi disconnected"
        let bluetooth = statusStore.status.bluetooth.isPoweredOn ? "Bluetooth on" : "Bluetooth off"
        let battery = statusStore.status.battery.percentage.map { "battery \($0) percent" } ?? "battery unavailable"
        let dots = BluetoothDotPresentation(bluetooth: statusStore.status.bluetooth, configuration: dotPreferences.configuration).summary
        return "\(wifi), \(bluetooth), \(battery). Dots: \(dots)"
    }

    private var metrics: DuoGlyphMetrics {
        #if DEBUG
        DuoGlyphMetrics(
            overallSize: CGFloat(overallSize),
            ringDiameter: CGFloat(ringDiameter),
            ringLineWidth: CGFloat(ringLineWidth),
            arcGap: arcGap,
            wifiSymbolSize: CGFloat(wifiSymbolSize),
            wifiYOffset: CGFloat(wifiYOffset),
            dotDiameter: CGFloat(dotDiameter),
            dotSpacing: CGFloat(dotSpacing),
            dotYOffset: CGFloat(dotYOffset)
        )
        #else
        .standard
        #endif
    }
}
