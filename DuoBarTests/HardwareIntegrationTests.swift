import XCTest
@testable import DuoBar

final class HardwareIntegrationTests: XCTestCase {
    @MainActor
    func testRealSystemStatusReadings() async throws {
        try requireHardwareValidation()

        let batteryService = BatteryService()
        let networkService = NetworkService()
        let audioService = AudioOutputService()
        var battery: BatteryStatus?
        var network: NetworkStatus?
        var audio: AudioStatus?

        batteryService.onStatusChange = { battery = $0 }
        networkService.onStatusChange = { network = $0 }
        audioService.onStatusChange = { audio = $0 }
        batteryService.start()
        networkService.start()
        audioService.start()

        try await Task.sleep(nanoseconds: 750_000_000)

        let batteryReading = try XCTUnwrap(battery)
        let networkReading = try XCTUnwrap(network)
        let audioReading = try XCTUnwrap(audio)
        XCTAssertTrue(batteryReading.isAvailable)
        XCTAssertTrue(networkReading.isAvailable)
        XCTAssertNotNil(audioReading.defaultOutput)

        print("HARDWARE battery=\(batteryReading.percentage.map(String.init) ?? "unknown") charging=\(batteryReading.isCharging)")
        print("HARDWARE network=\(networkReading.transport) connected=\(networkReading.isConnected) ssidAvailable=\(networkReading.ssid != nil) rssi=\(networkReading.rssi.map(String.init) ?? "unknown")")
        print("HARDWARE audio=\(audioReading.defaultOutput?.name ?? "unknown") transport=\(String(describing: audioReading.defaultOutput?.transport)) volume=\(audioReading.volume.percentage.map(String.init) ?? "unknown") settable=\(audioReading.volume.isSettable)")
        print("HARDWARE bluetoothAudioEndpoints=\(audioReading.connectedBluetoothOutputs.map(\.name))")
    }

    @MainActor
    func testBuiltInOutputVolumeRoundTrip() throws {
        try requireHardwareValidation()

        let service = AudioOutputService()
        var latest: AudioStatus?
        service.onStatusChange = { latest = $0 }
        service.start()

        let initial = try XCTUnwrap(latest)
        guard initial.defaultOutput?.transport == .builtIn else {
            throw XCTSkip("The current default output is not the Mac's built-in output")
        }
        guard initial.volume.isSettable, let originalLevel = initial.volume.level else {
            throw XCTSkip("The built-in output does not expose a settable scalar volume")
        }
        let originalMuted = initial.volume.isMuted
        defer {
            _ = service.setVolume(originalLevel)
            if initial.volume.isMuteSettable {
                _ = service.setMuted(originalMuted)
            }
        }

        let targetLevel = originalLevel > 0.55 ? originalLevel - 0.08 : originalLevel + 0.08
        XCTAssertTrue(service.setVolume(targetLevel))
        XCTAssertEqual(latest?.volume.level ?? -1, targetLevel, accuracy: 0.025)
    }

    @MainActor
    func testCurrentOutputCanStartVolumeFeedbackPlayback() async throws {
        try requireHardwareValidation()

        let service = AudioOutputService()
        var latest: AudioStatus?
        service.onStatusChange = { latest = $0 }
        service.start()

        let audio = try XCTUnwrap(latest)
        let output = try XCTUnwrap(audio.defaultOutput)
        guard audio.volume.isSettable,
              !audio.volume.isMuted,
              (audio.volume.level ?? 0) > 0
        else {
            throw XCTSkip("The current output cannot produce audible volume feedback")
        }

        XCTAssertTrue(VolumeFeedbackSound.play(on: output.uid))
        try await Task.sleep(nanoseconds: 200_000_000)
    }

    @MainActor
    func testCurrentBluetoothOutputPresentationClassification() throws {
        try requireHardwareValidation()

        let service = AudioOutputService()
        let batteryService = BatteryService()
        let networkService = NetworkService()
        var latest: AudioStatus?
        var battery: BatteryStatus?
        var network: NetworkStatus?
        service.onStatusChange = { latest = $0 }
        batteryService.onStatusChange = { battery = $0 }
        networkService.onStatusChange = { network = $0 }
        service.start()
        batteryService.start()
        networkService.start()

        let audio = try XCTUnwrap(latest)
        let output = try XCTUnwrap(audio.defaultOutput)
        guard output.transport.isBluetooth else {
            throw XCTSkip("The current default output is not a Bluetooth audio endpoint")
        }

        XCTAssertEqual(output.temporaryConnectionGlyph, .airPodsPro)
        XCTAssertEqual(output.modelUID?.lowercased(), "2027 4c")
        XCTAssertEqual(output.terminalType, .headphones)

        let current = SystemStatus(
            battery: try XCTUnwrap(battery),
            network: try XCTUnwrap(network),
            audio: audio,
            bluetooth: .unavailable
        )
        let old = SystemStatus(
            battery: current.battery,
            network: current.network,
            audio: AudioStatus(isAvailable: true, defaultOutput: nil, volume: .unavailable, connectedBluetoothOutputs: []),
            bluetooth: .unavailable
        )
        let event = try XCTUnwrap(StatusEventDetector.events(from: old, to: current).first)
        guard case let .audioDeviceConnected(detectedOutput) = event.kind else {
            return XCTFail("Expected a connection-only audio presentation event")
        }
        XCTAssertEqual(detectedOutput.temporaryConnectionGlyph, .airPodsPro)

        let normalGlyph = DuoGlyphState(status: current)
        let eventGlyph = DuoGlyphState(status: current, presentation: .event(event))
        XCTAssertEqual(eventGlyph.centerState, .airPodsPro)
        XCTAssertEqual(eventGlyph.batteryProgress, normalGlyph.batteryProgress)
        XCTAssertEqual(eventGlyph.batteryArcOpacity, normalGlyph.batteryArcOpacity)
        XCTAssertEqual(eventGlyph.volumeActiveDotCount, normalGlyph.volumeActiveDotCount)
        XCTAssertEqual(eventGlyph.volumeActiveDotCount, audio.volume.activeDotCount)

        XCTAssertTrue(StatusEventDetector.events(from: current, to: current).isEmpty)
        var disconnected = current
        disconnected.audio.connectedBluetoothOutputs = []
        disconnected.audio.defaultOutput = nil
        XCTAssertTrue(StatusEventDetector.events(from: current, to: disconnected).isEmpty)
        XCTAssertEqual(DuoGlyphState(status: current).centerState, normalGlyph.centerState)
    }

    @MainActor
    func testDefaultOutputRoundTrip() throws {
        try requireHardwareValidation()

        let service = AudioOutputService()
        var latest: AudioStatus?
        service.onStatusChange = { latest = $0 }
        service.start()

        let initial = try XCTUnwrap(latest)
        let originalUID = try XCTUnwrap(initial.defaultOutput?.uid)
        print("HARDWARE selectableOutputs=\(initial.selectableOutputs.map { "\($0.name)[\($0.uid)/\($0.transport)]" })")
        guard let other = initial.selectableOutputs.first(where: { $0.uid != originalUID }) else {
            throw XCTSkip("Need at least two output devices that can be the system default")
        }
        defer { _ = service.setDefaultOutput(uid: originalUID) }

        XCTAssertTrue(service.setDefaultOutput(uid: other.uid))
        XCTAssertEqual(latest?.defaultOutput?.uid, other.uid)
        XCTAssertTrue(service.setDefaultOutput(uid: originalUID))
        XCTAssertEqual(latest?.defaultOutput?.uid, originalUID)
    }

    private func requireHardwareValidation() throws {
        guard ProcessInfo.processInfo.environment["DUOBAR_HARDWARE_VALIDATION"] == "1" else {
            throw XCTSkip("Enable explicit real-hardware validation with DUOBAR_HARDWARE_VALIDATION=1")
        }
    }
}
