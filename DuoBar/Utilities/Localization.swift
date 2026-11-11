import Foundation

func localized(_ key: String) -> String {
    if let bundle = appLanguageBundleCache.bundle {
        return bundle.localizedString(forKey: key, value: nil, table: nil)
    }
    return NSLocalizedString(key, comment: "")
}

func localized(_ key: String, _ arguments: CVarArg...) -> String {
    String(format: localized(key), locale: AppLanguage.current.formatLocale, arguments: arguments)
}

/// Caches the .lproj bundle for the manually selected language. With the
/// system default selected this stays nil, which keeps the standard
/// NSLocalizedString behaviour bit-for-bit.
private let appLanguageBundleCache = AppLanguageBundleCache()

private final class AppLanguageBundleCache: @unchecked Sendable {
    private let lock = NSLock()
    private var cachedPreference: String?
    private var cachedBundle: Bundle?

    var bundle: Bundle? {
        let preference = UserDefaults.standard.string(forKey: PreferenceKeys.appLanguage) ?? ""
        lock.lock()
        defer { lock.unlock() }
        if cachedPreference != preference {
            cachedPreference = preference
            cachedBundle = AppLanguage(rawValue: preference)?.bundle
        }
        return cachedBundle
    }
}
