import Foundation

func localized(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

func localized(_ key: String, _ arguments: CVarArg...) -> String {
    String(format: localized(key), locale: .current, arguments: arguments)
}
