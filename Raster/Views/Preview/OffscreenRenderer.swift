import AppKit
import WebKit

/// A hidden `WKWebView` that loads the same `WebCore/index.html` as the live
/// preview, used by `ExportService` to produce PDF/HTML output. Always forces
/// the light/print palette (`data-mode="print"`) regardless of the app theme —
/// see CLAUDE.md "Export (PDF & ZIP)".
@MainActor
final class OffscreenRenderer: NSObject, WKNavigationDelegate {
    let bridge = WebBridge()
    private(set) var webView: WKWebView?

    private var loadContinuation: CheckedContinuation<Void, Error>?
    private var renderContinuation: CheckedContinuation<Void, Never>?

    func prepare(frame: CGRect) async throws {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(bridge, name: "raster")
        let webView = WKWebView(frame: frame, configuration: configuration)
        webView.navigationDelegate = self
        bridge.webView = webView
        self.webView = webView
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.loadContinuation = continuation
            webView.loadFileURL(WebCoreLocator.indexURL, allowingReadAccessTo: WebCoreLocator.directoryURL)
        }
    }

    /// Sets content on the print palette and waits for `didFinishRender`
    /// (fired once all Mermaid diagrams have finished rendering to SVG).
    func renderForPrint(markdown: String, language: String) async throws {
        guard let webView else { throw RasterError.exportFailed("Offscreen renderer wasn't prepared.") }
        _ = try await webView.evaluateJavaScript("document.documentElement.setAttribute('data-mode', 'print')")
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            renderContinuation = continuation
            bridge.onFinishRender = { [weak self] in
                self?.renderContinuation?.resume()
                self?.renderContinuation = nil
            }
            bridge.setLanguage(language)
            bridge.setContent(markdown)
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in
            loadContinuation?.resume()
            loadContinuation = nil
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            loadContinuation?.resume(throwing: error)
            loadContinuation = nil
        }
    }
}
