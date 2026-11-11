import Foundation

/// In-app language selection. The localizations the app ships are the cases
/// below; the default follows the system. The choice is stored under
/// `PreferenceKeys.appLanguage` and consulted by `localized(_:)` on every
/// call, so SwiftUI surfaces pick the new language up the next time they
/// render (Settings immediately, the popover on its next open).
enum AppLanguage: String, CaseIterable {
    case system = ""
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    case russian = "ru"
    case ukrainian = "uk"
    case thai = "th"

    /// The language's name written in itself, as is conventional in
    /// language pickers. "System Default" goes through the current
    /// localization like every other label.
    var displayName: String {
        switch self {
        case .system: return localized("System Default")
        case .english: return "English"
        case .simplifiedChinese: return "简体中文"
        case .traditionalChinese: return "繁體中文"
        case .russian: return "Русский"
        case .ukrainian: return "Українська"
        case .thai: return "ไทย"
        }
    }

    static var current: AppLanguage {
        let raw = UserDefaults.standard.string(forKey: PreferenceKeys.appLanguage) ?? ""
        return AppLanguage(rawValue: raw) ?? .system
    }

    /// The .lproj bundle for this language, or nil for the system default,
    /// where the main bundle's own resolution applies.
    var bundle: Bundle? {
        guard self != .system,
              let path = Bundle.main.path(forResource: rawValue, ofType: "lproj")
        else { return nil }
        return Bundle(path: path)
    }

    /// Locale for formatted strings (numbers, percentages, dates).
    var formatLocale: Locale {
        self == .system ? .current : Locale(identifier: rawValue)
    }
}
