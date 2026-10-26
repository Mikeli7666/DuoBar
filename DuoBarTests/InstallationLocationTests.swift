import Foundation
import XCTest
@testable import DuoBar

final class InstallationLocationTests: XCTestCase {
    func testMountedDiskImageBundleIsDetected() {
        let bundleURL = URL(fileURLWithPath: "/Volumes/DuoBar 1.3.0/DuoBar.app")
        XCTAssertTrue(InstallationLocation.isRunningFromDiskImage(bundleURL: bundleURL))
        XCTAssertTrue(InstallationLocation.shouldOfferApplicationsHelp(bundleURL: bundleURL, hasPresentedThisLaunch: false))
    }

    func testNonVolumeApplicationAndDevelopmentPathsDoNotPretendToBeDiskImages() {
        XCTAssertFalse(InstallationLocation.isRunningFromDiskImage(bundleURL: URL(fileURLWithPath: "/Applications/DuoBar.app")))
        XCTAssertFalse(InstallationLocation.isRunningFromDiskImage(bundleURL: URL(fileURLWithPath: "/Users/example/Applications/DuoBar.app")))
        XCTAssertFalse(InstallationLocation.isRunningFromDiskImage(bundleURL: URL(fileURLWithPath: "/private/var/folders/x/AppTranslocation/DuoBar.app")))
        XCTAssertFalse(InstallationLocation.isRunningFromDiskImage(bundleURL: URL(fileURLWithPath: "/tmp/DerivedData/Build/Products/Debug/DuoBar.app")))
        XCTAssertFalse(InstallationLocation.isRunningFromDiskImage(bundleURL: URL(fileURLWithPath: "/VolumesBackup/DuoBar.app")))
    }

    func testPromptIsOncePerLaunchDecision() {
        let bundleURL = URL(fileURLWithPath: "/Volumes/DuoBar/DuoBar.app")
        XCTAssertFalse(InstallationLocation.shouldOfferApplicationsHelp(bundleURL: bundleURL, hasPresentedThisLaunch: true))
    }
}
