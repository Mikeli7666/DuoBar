import Foundation

/// Pure installation-location policy. UI and Finder interaction stay in AppDelegate.
enum InstallationLocation {
    static func isRunningFromDiskImage(bundleURL: URL) -> Bool {
        bundleURL.standardizedFileURL.path.hasPrefix("/Volumes/")
    }

    static func shouldOfferApplicationsHelp(bundleURL: URL, hasPresentedThisLaunch: Bool) -> Bool {
        !hasPresentedThisLaunch && isRunningFromDiskImage(bundleURL: bundleURL)
    }
}
