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

    func testSoundSettingsURLIsWellFormed() {
        XCTAssertNotNil(URL(string: SystemSettingsOpener.soundURLString))
        XCTAssertTrue(SystemSettingsOpener.soundURLString.hasPrefix("x-apple.systempreferences:"))
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
}
