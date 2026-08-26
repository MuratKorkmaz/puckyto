import Foundation

/// Supported interface languages. English is the default.
enum AppLanguage: String, Codable, CaseIterable, Identifiable {
    case en
    case tr

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .en: return "English"
        case .tr: return "Türkçe"
        }
    }

    var flag: String {
        switch self {
        case .en: return "🇬🇧"
        case .tr: return "🇹🇷"
        }
    }
}

/// The translation table is keyed by the Turkish text: `L("Kapat")` returns "Close" in
/// English and the key itself in Turkish. Text missing from the table passes through,
/// so a missing translation only shows Turkish rather than causing an error.
enum Loc {
    nonisolated(unsafe) static var language: AppLanguage = .en
}

/// Translation of a static string
func L(_ key: String) -> String {
    guard Loc.language == .en else { return key }
    return Translations.en[key] ?? key
}

/// Translation with arguments: every `%@` in the key is filled from the arguments in order.
func Lf(_ key: String, _ args: Any...) -> String {
    var text = L(key)
    for arg in args {
        guard let range = text.range(of: "%@") else { break }
        let value = (arg as? String) ?? String(describing: arg)
        text.replaceSubrange(range, with: value)
    }
    return text
}
