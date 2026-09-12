import AppKit
import SwiftUI
import XCTest
@testable import DuoBar

final class PopoverLayoutTests: XCTestCase {
    @MainActor
    func testBluetoothExplanationsFitAtPopoverWidth() throws {
        let content = BluetoothControlView(
            statusStore: SystemStatusStore(startServices: false),
            controls: BluetoothControls(),
            openSettings: {}
        )
        .frame(width: 272)
        .fixedSize(horizontal: false, vertical: true)
        .padding(12)
        .background(Color.white)
        .environment(\.colorScheme, .light)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        let image = try XCTUnwrap(renderer.nsImage)
        XCTAssertGreaterThan(image.size.height, 100)
        let bitmap = try XCTUnwrap(image.tiffRepresentation.flatMap(NSBitmapImageRep.init(data:)))
        let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        try png.write(to: FileManager.default.temporaryDirectory.appendingPathComponent("DuoBar-BluetoothControls.png"))
    }

    @MainActor
    func testBatteryControlsKeepTheirSizeWhenPercentageChanges() async throws {
        let suite = "DuoBarTests.Layout.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let content = BatteryControlView(openSettings: {})
            .frame(width: 272)
            .fixedSize(horizontal: false, vertical: true)
            .defaultAppStorage(defaults)
        let host = NSHostingController(rootView: content)
        host.sizingOptions = [.preferredContentSize]
        host.view.layoutSubtreeIfNeeded()
        let initialSize = host.view.fittingSize

        for enabled in [true, false, true, false, true] {
            defaults.set(enabled, forKey: PreferenceKeys.showMenuBarBatteryPercentage)
            try await Task.sleep(for: .milliseconds(40))
            host.view.layoutSubtreeIfNeeded()
            XCTAssertEqual(host.view.fittingSize.width, initialSize.width, accuracy: 0.5)
            XCTAssertEqual(host.view.fittingSize.height, initialSize.height, accuracy: 0.5)
        }

        let renderer = ImageRenderer(content: content.padding(12).background(Color.white).environment(\.colorScheme, .light))
        renderer.scale = 2
        let image = try XCTUnwrap(renderer.nsImage)
        // Two toggles, a wrapping explanation, and the settings button must all fit.
        XCTAssertGreaterThan(image.size.height, 100)
        let bitmap = try XCTUnwrap(image.tiffRepresentation.flatMap(NSBitmapImageRep.init(data:)))
        let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        try png.write(to: FileManager.default.temporaryDirectory.appendingPathComponent("DuoBar-BatteryControls.png"))
    }
}
