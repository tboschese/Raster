import Foundation
import WebKit

struct OutlineEntry: Identifiable, Equatable {
    let level: Int
    let title: String
    let id: String

    init?(raw: [String: Any]) {
        guard let level = raw["level"] as? Int,
              let title = raw["title"] as? String,
              let id = raw["id"] as? String else { return nil }
        self.level = level
        self.title = title
        self.id = id
    }
}

struct DocumentStats: Equatable {
    var words: Int
    var readingMinutes: Int

    init(words: Int = 0, readingMinutes: Int = 0) {
        self.words = words
        self.readingMinutes = readingMinutes
    }

    init?(raw: [String: Any]) {
        guard let words = raw["words"] as? Int, let minutes = raw["readingMinutes"] as? Int else { return nil }
        self.words = words
        self.readingMinutes = minutes
    }
}

struct FindResult: Equatable {
    var current: Int
    var total: Int

    init?(raw: [String: Any]) {
        guard let current = raw["current"] as? Int, let total = raw["total"] as? Int else { return nil }
        self.current = current
        self.total = total
    }
}

/// The JS ⇄ Swift bridge described in CLAUDE.md. Receives
/// `window.webkit.messageHandlers.raster.postMessage({type, payload})` calls
/// from engine.js (JS → Swift) and issues `window.raster.<fn>(...)` commands
/// back (Swift → JS) via `evaluateJavaScript`.
final class WebBridge: NSObject, WKScriptMessageHandler {
    weak var webView: WKWebView?

    var onEditMarkdown: ((String) -> Void)?
    var onUpdateOutline: (([OutlineEntry]) -> Void)?
    var onUpdateStats: ((DocumentStats) -> Void)?
    var onChangeActiveHeading: ((String) -> Void)?
    var onFindResult: ((FindResult) -> Void)?
    var onFinishRender: (() -> Void)?
    var onRequestSave: (() -> Void)?

    // MARK: JS → Swift

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any], let type = body["type"] as? String else { return }
        let payload = body["payload"]
        switch type {
        case "didEditMarkdown":
            if let markdown = payload as? String { onEditMarkdown?(markdown) }
        case "didUpdateOutline":
            if let raw = payload as? [[String: Any]] {
                onUpdateOutline?(raw.compactMap(OutlineEntry.init(raw:)))
            }
        case "didUpdateStats":
            if let raw = payload as? [String: Any], let stats = DocumentStats(raw: raw) {
                onUpdateStats?(stats)
            }
        case "didChangeActiveHeading":
            if let raw = payload as? [String: Any], let id = raw["id"] as? String {
                onChangeActiveHeading?(id)
            }
        case "findResult":
            if let raw = payload as? [String: Any], let result = FindResult(raw: raw) {
                onFindResult?(result)
            }
        case "didFinishRender":
            onFinishRender?()
        case "requestSave":
            onRequestSave?()
        default:
            break
        }
    }

    // MARK: Swift → JS

    func setContent(_ markdown: String) {
        call("setContent", args: [markdown])
    }

    func setTheme(_ theme: Theme) {
        call("setTheme", args: [theme.rawValue])
    }

    func setMode(editing: Bool) {
        call("setMode", args: [editing ? "edit" : "read"])
    }

    func setReadingFont(_ font: ReadingFont) {
        call("setReadingFont", args: [font.rawValue])
    }

    func setLanguage(_ bcp47: String) {
        call("setLanguage", args: [bcp47])
    }

    func setLayout(_ mode: EditorMode) {
        call("setLayout", args: [mode == .reading ? "reading" : "split"])
    }

    func requestCommit() {
        call("requestCommit", args: [])
    }

    func find(query: String, direction: String) {
        call("find", args: [query, direction])
    }

    func scrollToHeading(_ id: String) {
        call("scrollToHeading", args: [id])
    }

    private func call(_ function: String, args: [String]) {
        let encoded = args.map(Self.jsStringLiteral)
        webView?.evaluateJavaScript("window.raster.\(function)(\(encoded.joined(separator: ", ")))", completionHandler: nil)
    }

    /// JSON-encodes so document content (quotes, backslashes, newlines) can
    /// never break out of the JS string literal it's interpolated into.
    private static func jsStringLiteral(_ s: String) -> String {
        guard let data = try? JSONEncoder().encode(s), let json = String(data: data, encoding: .utf8) else {
            return "\"\""
        }
        return json
    }
}
