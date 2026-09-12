import AppKit
import SwiftUI
import XCTest
@testable import DuoBar

final class BluetoothDotTests: XCTestCase {
    func testPowerModePreservesOriginalAppearance() {
        for (available, powered, opacity) in [(true, true, 1.0), (true, false, 0.25), (false, false, 0.14)] {
            let result = BluetoothDotPresentation(
                bluetooth: BluetoothStatus(isAvailable: available, isPoweredOn: powered), configuration: .standard
            )
            XCTAssertEqual(result.dots, Array(repeating: .init(opacity: opacity), count: 4))
        }
    }

    func testCountCapsAtFourAndIgnoresDisconnectedAndDuplicateDevices() {
        var devices = (0..<6).map { device("\($0)") }
        devices.append(device("0"))
        devices.append(device("offline", connected: false))
        let result = presentation(devices, mode: .connectedCount)
        XCTAssertEqual(result.dots, Array(repeating: .on, count: 4))
        XCTAssertEqual(result.summary, "6 connected devices")
        XCTAssertEqual(presentation([], mode: .connectedCount).dots, Array(repeating: .off, count: 4))
    }

    func testPinsKeepPositionsWhenDeviceListOrderChanges() {
        let config = BluetoothDotConfiguration(mode: .pinnedDevices, pinnedDeviceIDs: ["b", "a", "missing", ""])
        let devices = [device("a"), device("b", connected: false)]
        let first = BluetoothDotPresentation(bluetooth: status(devices), configuration: config)
        let reordered = BluetoothDotPresentation(bluetooth: status(devices.reversed()), configuration: config)
        XCTAssertEqual(first, reordered)
        XCTAssertEqual(first.dots, [.off, .on, .unknown, .unknown])
        let reconnected = BluetoothDotPresentation(bluetooth: status([device("b"), device("a")]), configuration: config)
        XCTAssertEqual(reconnected.dots, [.on, .on, .unknown, .unknown])
    }

    func testDuplicatePinsDoNotLightMultipleSlots() {
        let config = BluetoothDotConfiguration(mode: .pinnedDevices, pinnedDeviceIDs: ["a", "a", "b", "c", "d"])
        XCTAssertEqual(config.slots, ["a", "", "b", "c"])
        let result = BluetoothDotPresentation(bluetooth: status([device("a")]), configuration: config)
        XCTAssertEqual(result.dots, [.on, .unknown, .unknown, .unknown])
    }

    func testBatteryUsesQuarterStepsIncludingRealZero() {
        for (percentage, count) in [(0, 0), (1, 1), (25, 1), (26, 2), (50, 2), (51, 3), (75, 3), (76, 4), (100, 4)] {
            let result = presentation([device("a", battery: percentage)], mode: .accessoryBattery)
            XCTAssertEqual(result.dots.filter { $0 == .on }.count, count, "\(percentage)%")
            XCTAssertFalse(result.dots.contains(where: \.isHollow))
        }
    }

    func testMissingInvalidAndDisconnectedBatteryReadingsAreUnknown() {
        for devices in [[], [device("a")], [device("a", battery: -1)], [device("a", battery: 101)], [device("a", connected: false, battery: 90)]] {
            XCTAssertEqual(presentation(devices, mode: .accessoryBattery).dots, Array(repeating: .unknown, count: 4))
        }
        var bluetooth = status([device("a", battery: 90)])
        bluetooth.isPoweredOn = false
        let result = BluetoothDotPresentation(bluetooth: bluetooth, configuration: .init(mode: .accessoryBattery, batteryDeviceID: "a"))
        XCTAssertEqual(result.dots, Array(repeating: .unknown, count: 4))
        XCTAssertEqual(result.summary, "Bluetooth off")
    }

    func testBatteryReaderRejectsNonPercentagesAndNormalizesDeviceAddresses() {
        XCTAssertEqual(AccessoryBatteryReader.normalizedAddress("AA-BB-CC-DD-EE-FF"), "aabbccddeeff")
        XCTAssertEqual(AccessoryBatteryReader.normalizedAddress("aa:bb:cc:dd:ee:ff"), "aabbccddeeff")
        XCTAssertNil(AccessoryBatteryReader.normalizedAddress("Mouse"))
        XCTAssertNil(AccessoryBatteryReader.normalizedAddress("gg:bb:cc:dd:ee:ff"))
        for value: Any in [true, -1, 101, 42.5, "80"] {
            XCTAssertNil(AccessoryBatteryReader.percentage(value))
        }
        XCTAssertEqual(AccessoryBatteryReader.percentage(0), 0)
        XCTAssertEqual(AccessoryBatteryReader.percentage(100), 100)
    }

    @MainActor
    func testPreferencesRestoreModeAndDeviceAssignments() throws {
        let suite = "DuoBarTests.DotPreferences.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("a", forKey: PreferenceKeys.bluetoothDotSlot1)
        defaults.set("b", forKey: PreferenceKeys.bluetoothDotSlot2)
        defaults.set("c", forKey: PreferenceKeys.bluetoothDotSlot3)
        defaults.set("d", forKey: PreferenceKeys.bluetoothDotSlot4)
        defaults.set("c", forKey: PreferenceKeys.bluetoothDotBatteryDevice)
        for mode in BluetoothDotMode.allCases {
            defaults.set(mode.rawValue, forKey: PreferenceKeys.bluetoothDotMode)
            var captured: BluetoothDotConfiguration?
            let renderer = ImageRenderer(content: DotPreferencesProbe { captured = $0 }.defaultAppStorage(defaults))
            XCTAssertNotNil(renderer.nsImage)
            XCTAssertEqual(captured, .init(mode: mode, pinnedDeviceIDs: ["a", "b", "c", "d"], batteryDeviceID: "c"))
        }
    }

    @MainActor
    func testRenderDotModes() throws {
        let bluetooth = status([device("a", battery: 50), device("b", connected: false), device("c")])
        let system = SystemStatus(battery: .init(percentage: 75, isCharging: false, isPluggedIn: false, isFullyCharged: false, isAvailable: true), wifi: .init(isAvailable: true, isPoweredOn: true, isConnected: true, ssid: "Test", rssi: -45), bluetooth: bluetooth)
        let gallery = HStack(spacing: 16) {
            ForEach(BluetoothDotMode.allCases) { mode in
                VStack(spacing: 10) {
                    DuoGlyphView(status: system, metrics: .standard.sized(64), animationsEnabled: false,
                                 dotConfiguration: .init(mode: mode, pinnedDeviceIDs: ["b", "a", "c", ""], batteryDeviceID: "a"))
                    Text(mode.title).font(.system(size: 11))
                }.frame(width: 145)
            }
        }
        .padding(20)
        .background(Color.white)
        .environment(\.colorScheme, .light)
        let renderer = ImageRenderer(content: gallery)
        renderer.scale = 2
        let image = try XCTUnwrap(renderer.nsImage)
        let bitmap = try XCTUnwrap(image.tiffRepresentation.flatMap(NSBitmapImageRep.init(data:)))
        let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        try png.write(to: FileManager.default.temporaryDirectory.appendingPathComponent("DuoBar-DotModes.png"))
    }

    private func device(_ id: String, connected: Bool = true, battery: Int? = nil) -> PairedBluetoothDevice {
        .init(id: id, name: "Device \(id)", isConnected: connected, batteryPercentage: battery)
    }
    private func status(_ devices: [PairedBluetoothDevice]) -> BluetoothStatus {
        .init(isAvailable: true, isPoweredOn: true, devices: devices)
    }
    private func presentation(_ devices: [PairedBluetoothDevice], mode: BluetoothDotMode) -> BluetoothDotPresentation {
        BluetoothDotPresentation(bluetooth: status(devices), configuration: .init(mode: mode, batteryDeviceID: "a"))
    }
}

private struct DotPreferencesProbe: View {
    private var preferences = BluetoothDotPreferences()
    let onRead: (BluetoothDotConfiguration) -> Void

    var body: some View {
        let _ = onRead(preferences.configuration)
        Color.clear.frame(width: 1, height: 1)
    }
}
