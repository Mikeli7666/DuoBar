import XCTest
@testable import DuoBar

final class PopoverControlsTests: XCTestCase {
    func testSelectableOutputsSkipDeadDevicesAndDeduplicate() {
        let live = AudioDeviceStatus(uid: "built-in", name: "Speakers", transport: .builtIn, isAlive: true)
        let duplicate = AudioDeviceStatus(uid: "built-in", name: "Speakers Copy", transport: .builtIn, isAlive: true)
        let dead = AudioDeviceStatus(uid: "dead", name: "Old DAC", transport: .usb, isAlive: false)
        let headphones = AudioDeviceStatus(uid: "bt", name: "Headphones", transport: .bluetooth, isAlive: true)

        let audio = AudioStatus(
            isAvailable: true,
            defaultOutput: live,
            volume: .unavailable,
            connectedBluetoothOutputs: [headphones],
            availableOutputs: [live, duplicate, dead, headphones]
        )

        XCTAssertEqual(audio.selectableOutputs.map(\.uid), ["built-in", "bt"])
    }

    func testSelectableOutputsFallBackToDefaultWhenListIsEmpty() {
        let live = AudioDeviceStatus(uid: "built-in", name: "Speakers", transport: .builtIn, isAlive: true)
        let audio = AudioStatus(
            isAvailable: true,
            defaultOutput: live,
            volume: .unavailable,
            connectedBluetoothOutputs: []
        )

        XCTAssertEqual(audio.selectableOutputs.map(\.uid), ["built-in"])
    }

    func testNetworkSettingsPaneFollowsTransport() {
        XCTAssertEqual(SystemSettingsOpener.pane(for: wifiNetwork()), .wifi)
        XCTAssertEqual(SystemSettingsOpener.pane(for: ethernetNetwork()), .network)
        XCTAssertEqual(SystemSettingsOpener.pane(for: .unavailable), .wifi)
    }

    func testSystemSettingsURLsAreWellFormed() {
        for pane in [SystemSettingsOpener.Pane.wifi, .network, .battery, .sound] {
            let urls = SystemSettingsOpener.urlStrings(for: pane)
            XCTAssertFalse(urls.isEmpty, "Missing URLs for \(pane)")
            for string in urls {
                XCTAssertNotNil(URL(string: string), string)
                XCTAssertTrue(string.hasPrefix("x-apple.systempreferences:"), string)
            }
        }
    }

    func testDebugAudioPickerExposesMultipleOutputs() {
        let audio = DebugAudioDeviceState.airPods.status
        XCTAssertEqual(audio.defaultOutput?.uid, "debug-AirPods Pro")
        XCTAssertEqual(audio.selectableOutputs.map(\.uid), [
            "debug-MacBook Speakers",
            "debug-AirPods Pro",
            "debug-Bluetooth Headphones"
        ])
    }

    @MainActor
    func testDebugStoreCanSwitchSimulatedOutput() {
        let store = SystemStatusStore(startServices: false)
        store.applyDebugAudioDeviceState(.builtIn)
        XCTAssertTrue(store.setDefaultOutput(uid: "debug-AirPods Pro"))
        XCTAssertEqual(store.status.audio.defaultOutput?.uid, "debug-AirPods Pro")
        XCTAssertTrue(store.status.audio.defaultOutput?.transport.isBluetooth ?? false)
    }

    @MainActor
    func testAudioOutputServiceIncludesDefaultInSelectableOutputs() {
        let service = AudioOutputService()
        var latest: AudioStatus?
        service.onStatusChange = { latest = $0 }
        service.start()

        guard let audio = latest else {
            return XCTFail("AudioOutputService did not publish an initial reading")
        }
        guard let uid = audio.defaultOutput?.uid else { return }
        XCTAssertTrue(audio.selectableOutputs.contains(where: { $0.uid == uid }))
        XCTAssertFalse(service.setDefaultOutput(uid: "missing-output-device"))
    }

    private func wifiNetwork() -> NetworkStatus {
        NetworkStatus(
            isAvailable: true,
            isConnected: true,
            transport: .wifi,
            interfaceName: "en0",
            isWiFiPoweredOn: true,
            ssid: "Home",
            rssi: -42
        )
    }

    private func ethernetNetwork() -> NetworkStatus {
        NetworkStatus(
            isAvailable: true,
            isConnected: true,
            transport: .ethernet,
            interfaceName: "en1",
            isWiFiPoweredOn: true,
            ssid: nil,
            rssi: nil
        )
    }
}
