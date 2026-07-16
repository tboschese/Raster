import Foundation

enum Theme: String, CaseIterable, Identifiable {
    case dark
    case light

    var id: String { rawValue }
}

enum ReadingFont: String, CaseIterable, Identifiable {
    case serif
    case sans

    var id: String { rawValue }
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case en
    case ptBR = "pt-BR"

    var id: String { rawValue }

    /// BCP-47 tag to push into the WebView, or `nil` for `.system` (resolve via `LocalizationService`).
    var bcp47: String? {
        switch self {
        case .system: return nil
        case .en: return "en"
        case .ptBR: return "pt-BR"
        }
    }
}

/// Persists theme, reading font, and the language override in `UserDefaults`.
@MainActor
final class PreferencesStore: ObservableObject {
    @Published var theme: Theme {
        didSet { defaults.set(theme.rawValue, forKey: Keys.theme) }
    }
    @Published var readingFont: ReadingFont {
        didSet { defaults.set(readingFont.rawValue, forKey: Keys.readingFont) }
    }
    @Published var language: AppLanguage {
        didSet {
            defaults.set(language.rawValue, forKey: Keys.language)
            LocalizationService.apply(language)
        }
    }

    private let defaults: UserDefaults

    private enum Keys {
        static let theme = "raster.theme"
        static let readingFont = "raster.readingFont"
        static let language = "raster.language"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        theme = Theme(rawValue: defaults.string(forKey: Keys.theme) ?? "") ?? .dark
        readingFont = ReadingFont(rawValue: defaults.string(forKey: Keys.readingFont) ?? "") ?? .serif
        language = AppLanguage(rawValue: defaults.string(forKey: Keys.language) ?? "") ?? .system
    }
}
