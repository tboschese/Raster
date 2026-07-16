import Foundation

/// Locates the bundled `WebCore/` folder reference (marked/highlight.js/mermaid/
/// turndown + engine.js), loaded via `file://` — see CLAUDE.md "WKWebView + file://".
enum WebCoreLocator {
    /// `WebCore/` is guaranteed to exist by the app's build settings (it's a
    /// folder reference added to every target); a missing bundle means the
    /// build itself is misconfigured, not a recoverable runtime condition.
    static var directoryURL: URL {
        guard let url = Bundle.main.url(forResource: "WebCore", withExtension: nil) else {
            fatalError("WebCore resource bundle is missing from the app bundle.")
        }
        return url
    }

    static var indexURL: URL {
        directoryURL.appendingPathComponent("index.html")
    }
}
