import Foundation
import XCTest
@testable import DuoBar

final class LocalizationTests: XCTestCase {
    private let requiredKeys = [
        "Network",
        "Wi-Fi",
        "Wi-Fi power",
        "Wi-Fi control unavailable",
        "Unable to change Wi-Fi power",
        "Off",
        "Volume",
        "Battery",
        "Audio Output",
        "Audio Device",
        "Settings",
        "Quit DuoBar",
        "Icon Size",
        "Open on Hover",
        "Open DuoBar when the pointer moves over the menu bar icon.",
        "Launch DuoBar at login",
        "Controlled by device",
        "Charging",
        "Fully charged",
        "Offline",
        "Automatic",
        "Prefer CPU",
        "Prefer Memory",
        "Prefer Thermal",
        "%d%%",
        "volume %d percent",
        "battery %d percent",
        "Sound Settings…",
        "Select audio output",
        "Open Wi-Fi Settings",
        "Open Network Settings",
        "Open Battery Settings",
        "No output devices"
    ]

    func testAllSupportedLocalizationResourcesExist() {
        for language in ["en", "ru", "uk", "zh-Hans", "zh-Hant"] {
            XCTAssertNotNil(localizationBundle(for: language), "Missing \(language).lproj")
        }
    }

    func testRequiredProductionKeysArePresentAndNonEmptyInEverySupportedLanguage() {
        for language in ["en", "ru", "uk", "zh-Hans", "zh-Hant"] {
            guard let bundle = localizationBundle(for: language) else {
                return XCTFail("Missing \(language).lproj")
            }
            guard let strings = localizationStrings(in: bundle) else {
                return XCTFail("Missing Localizable.strings in \(language)")
            }

            for key in requiredKeys {
                guard let value = strings[key] as? String else {
                    return XCTFail("Missing \(key) in \(language)")
                }
                XCTAssertFalse(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "Empty \(key) in \(language)")
            }
        }
    }

    func testFormatPlaceholdersRemainCompatible() {
        for language in ["en", "ru", "uk", "zh-Hans", "zh-Hant"] {
            guard let bundle = localizationBundle(for: language) else {
                return XCTFail("Missing \(language).lproj")
            }

            XCTAssertTrue(NSLocalizedString("%d%%", bundle: bundle, comment: "").contains("%d"))
            XCTAssertTrue(NSLocalizedString("volume %d percent", bundle: bundle, comment: "").contains("%d"))
            XCTAssertTrue(NSLocalizedString("battery %d percent", bundle: bundle, comment: "").contains("%d"))
        }
    }

    func testPreferencePersistenceIdentifiersRemainStable() {
        XCTAssertEqual(PerformancePreference.automatic.rawValue, "Automatic")
        XCTAssertEqual(PerformancePreference.cpu.rawValue, "Prefer CPU")
        XCTAssertEqual(PerformancePreference.memory.rawValue, "Prefer Memory")
        XCTAssertEqual(PerformancePreference.thermal.rawValue, "Prefer Thermal")
    }

    func testUnsupportedLocaleFallsBackToEnglishBundle() {
        guard let englishBundle = localizationBundle(for: "en") else {
            return XCTFail("Missing English localization bundle")
        }
        XCTAssertEqual(
            NSLocalizedString("Settings", bundle: englishBundle, comment: ""),
            "Settings"
        )
    }

    private func localizationBundle(for language: String) -> Bundle? {
        guard let resourceURL = Bundle.main.resourceURL else { return nil }
        return Bundle(url: resourceURL.appending(path: "\(language).lproj"))
    }

    private func localizationStrings(in bundle: Bundle) -> NSDictionary? {
        guard let url = bundle.url(forResource: "Localizable", withExtension: "strings") else {
            return nil
        }
        return NSDictionary(contentsOf: url)
    }
}
