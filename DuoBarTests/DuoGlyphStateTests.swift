import AppKit
import SwiftUI
import XCTest
@testable import DuoBar

final class DuoGlyphStateTests: XCTestCase {
    func testBatteryLevelsMapLinearlyToArcProgress() {
        for percentage in [100, 75, 50, 25, 10, 0] {
            let state = DuoGlyphState(status: makeStatus(batteryPercentage: percentage))
            XCTAssertEqual(state.batteryProgress, Double(percentage) / 100, accuracy: 0.0001)
        }
    }

    func testArcKeepsLeftAnchorAndMovesOnlyItsRightEndpoint() {
        let metrics = DuoGlyphMetrics.standard
        let full = DuoArcShape(
            startDegrees: metrics.arcStartDegrees,
            endDegrees: metrics.arcEndDegrees,
            progress: 1
        )
        let half = DuoArcShape(
            startDegrees: metrics.arcStartDegrees,
            endDegrees: metrics.arcEndDegrees,
            progress: 0.5
        )
        let empty = DuoArcShape(
            startDegrees: metrics.arcStartDegrees,
            endDegrees: metrics.arcEndDegrees,
            progress: 0
        )

        XCTAssertEqual(full.startDegrees, half.startDegrees)
        XCTAssertEqual(half.startDegrees, empty.startDegrees)
        XCTAssertEqual(full.visibleEndDegrees, metrics.arcEndDegrees, accuracy: 0.0001)
        XCTAssertEqual(half.visibleEndDegrees, metrics.arcStartDegrees + (metrics.arcEndDegrees - metrics.arcStartDegrees) / 2, accuracy: 0.0001)
        XCTAssertEqual(empty.visibleEndDegrees, metrics.arcStartDegrees, accuracy: 0.0001)
    }

    func testWiFiSignalLevelsUseNormalizedRSSIState() {
        XCTAssertEqual(wifi(rssi: -42).signalLevel, .strong)
        XCTAssertEqual(wifi(rssi: -67).signalLevel, .medium)
        XCTAssertEqual(wifi(rssi: -84).signalLevel, .weak)

        var disconnected = wifi(rssi: nil)
        disconnected.isConnected = false
        XCTAssertEqual(disconnected.signalLevel, .disconnected)

        disconnected.isPoweredOn = false
        XCTAssertEqual(disconnected.signalLevel, .disabled)
    }

    func testBluetoothDotOpacityPreservesAllFourDotStates() {
        let on = DuoGlyphState(status: makeStatus(bluetooth: BluetoothStatus(isAvailable: true, isPoweredOn: true)))
        let off = DuoGlyphState(status: makeStatus(bluetooth: BluetoothStatus(isAvailable: true, isPoweredOn: false)))
        let unavailable = DuoGlyphState(status: makeStatus(bluetooth: .unavailable))

        XCTAssertEqual(on.bluetoothDotOpacity, 1)
        XCTAssertEqual(off.bluetoothDotOpacity, 0.25)
        XCTAssertEqual(unavailable.bluetoothDotOpacity, 0.14)
    }

    func testIndependentLayerCombination() {
        let status = SystemStatus(
            battery: BatteryStatus(
                percentage: 25,
                isCharging: true,
                isPluggedIn: true,
                isFullyCharged: false,
                isAvailable: true
            ),
            wifi: wifi(rssi: -42),
            bluetooth: BluetoothStatus(isAvailable: true, isPoweredOn: true)
        )

        let state = DuoGlyphState(status: status)
        XCTAssertEqual(state.batteryProgress, 0.25)
        XCTAssertTrue(state.isCharging)
        XCTAssertEqual(state.wifiLevel, .strong)
        XCTAssertEqual(state.bluetoothDotOpacity, 1)
    }

    @MainActor
    func testRenderAcceptanceStateGallery() throws {
        let scenarios = [
            PreviewScenario(name: "100%", status: makeStatus(batteryPercentage: 100)),
            PreviewScenario(name: "75%", status: makeStatus(batteryPercentage: 75)),
            PreviewScenario(name: "50%", status: makeStatus(batteryPercentage: 50)),
            PreviewScenario(name: "25%", status: makeStatus(batteryPercentage: 25)),
            PreviewScenario(name: "10%", status: makeStatus(batteryPercentage: 10)),
            PreviewScenario(
                name: "25% + charge",
                status: makeStatus(batteryPercentage: 25, charging: true)
            ),
            PreviewScenario(
                name: "weak + BT off",
                status: makeStatus(
                    batteryPercentage: 75,
                    wifi: wifi(rssi: -84),
                    bluetooth: BluetoothStatus(isAvailable: true, isPoweredOn: false)
                )
            ),
            PreviewScenario(
                name: "offline + BT on",
                status: makeStatus(
                    batteryPercentage: 100,
                    wifi: WiFiStatus(isAvailable: true, isPoweredOn: true, isConnected: false, ssid: nil, rssi: nil)
                )
            ),
            PreviewScenario(
                name: "BT unavailable",
                status: makeStatus(batteryPercentage: 100, bluetooth: .unavailable)
            )
        ]

        let gallery = HStack(alignment: .top, spacing: 18) {
            ForEach(scenarios) { scenario in
                VStack(spacing: 8) {
                    DuoGlyphView(
                        status: scenario.status,
                        metrics: DuoGlyphMetrics.standard.sized(88),
                        animationsEnabled: false
                    )
                    Text(scenario.name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                }
                .frame(width: 134)
            }
        }
        .padding(20)
        .background(Color.black)
        .environment(\.colorScheme, .dark)

        let renderer = ImageRenderer(content: gallery)
        renderer.scale = 2
        let image = try XCTUnwrap(renderer.nsImage)
        let representation = try XCTUnwrap(image.tiffRepresentation.flatMap(NSBitmapImageRep.init(data:)))
        let png = try XCTUnwrap(representation.representation(using: .png, properties: [:]))
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("DuoBar-StateGallery.png")
        try png.write(to: outputURL, options: .atomic)

        XCTAssertGreaterThan(png.count, 1_000)
    }

    @MainActor
    func testChargingIndicatorFitsBesideGlyphAtMenuBarSize() throws {
        let metrics = DuoGlyphMetrics.standard
        let normal = ImageRenderer(content: DuoGlyphView(
            status: makeStatus(), animationsEnabled: false
        ))
        let charging = ImageRenderer(content: DuoGlyphView(
            status: makeStatus(batteryPercentage: 25, charging: true), animationsEnabled: false
        ))
        let normalImage = try XCTUnwrap(normal.nsImage)
        let chargingImage = try XCTUnwrap(charging.nsImage)
        XCTAssertEqual(chargingImage.size.width - normalImage.size.width, metrics.chargingIndicatorWidth, accuracy: 0.5)
        XCTAssertEqual(chargingImage.size.height, normalImage.size.height, accuracy: 0.5)

        let gallery = VStack(spacing: 0) {
            ForEach([ColorScheme.light, .dark], id: \.self) { scheme in
                HStack(spacing: 20) {
                    ForEach([10, 25, 75, 100], id: \.self) { level in
                        VStack(spacing: 8) {
                            DuoGlyphView(status: self.makeStatus(batteryPercentage: level), animationsEnabled: false)
                            DuoGlyphView(status: self.makeStatus(batteryPercentage: level, charging: true), animationsEnabled: false)
                        }
                        .frame(width: 50)
                    }
                }
                .padding(20)
                .background(scheme == .dark ? Color.black : Color.white)
                .environment(\.colorScheme, scheme)
            }
        }
        let renderer = ImageRenderer(content: gallery)
        renderer.scale = 3
        let image = try XCTUnwrap(renderer.nsImage)
        let bitmap = try XCTUnwrap(image.tiffRepresentation.flatMap(NSBitmapImageRep.init(data:)))
        let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        try png.write(to: FileManager.default.temporaryDirectory.appendingPathComponent("DuoBar-ChargingGallery.png"))
    }

    private func makeStatus(
        batteryPercentage: Int = 100,
        charging: Bool = false,
        wifi: WiFiStatus? = nil,
        bluetooth: BluetoothStatus = BluetoothStatus(isAvailable: true, isPoweredOn: true)
    ) -> SystemStatus {
        SystemStatus(
            battery: BatteryStatus(
                percentage: batteryPercentage,
                isCharging: charging,
                isPluggedIn: charging,
                isFullyCharged: false,
                isAvailable: true
            ),
            wifi: wifi ?? self.wifi(rssi: -42),
            bluetooth: bluetooth
        )
    }

    private func wifi(rssi: Int?) -> WiFiStatus {
        WiFiStatus(
            isAvailable: true,
            isPoweredOn: true,
            isConnected: true,
            ssid: "Test",
            rssi: rssi
        )
    }
}

private struct PreviewScenario: Identifiable {
    let name: String
    let status: SystemStatus

    var id: String { name }
}
