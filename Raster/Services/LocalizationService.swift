import Foundation

/// Wraps the mechanism for overriding the app's UI language so the rest of the
/// app only ever calls `apply(_:)` — never touches `AppleLanguages` directly.
/// The override takes effect on next launch; macOS relaunches SwiftUI apps
/// cleanly enough that we simply prompt nothing and let it apply on restart.
enum LocalizationService {
    private static let appleLanguagesKey = "AppleLanguages"

    static func apply(_ language: AppLanguage) {
        guard let tag = language.bcp47 else {
            UserDefaults.standard.removeObject(forKey: appleLanguagesKey)
            return
        }
        UserDefaults.standard.set([tag], forKey: appleLanguagesKey)
    }

    /// The BCP-47 tag to push into the WebView via `setLanguage`, resolving
    /// `.system` against the user's actual preferred language.
    static func resolvedBCP47(for language: AppLanguage) -> String {
        if let tag = language.bcp47 { return tag }
        let preferred = Locale.preferredLanguages.first ?? "en"
        return preferred.hasPrefix("pt") ? "pt-BR" : "en"
    }
}
