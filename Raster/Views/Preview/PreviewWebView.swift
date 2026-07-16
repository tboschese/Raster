import SwiftUI
import WebKit

/// Hosts the rendered Markdown preview / reading-mode WYSIWYG. Wires the
/// shared `WebBridge` to a freshly created `WKWebView` and loads
/// `WebCore/index.html` with read access to the whole `WebCore/` directory.
struct PreviewWebView: NSViewRepresentable {
    let bridge: WebBridge
    let onReady: () -> Void

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(bridge, name: "raster")

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.underPageBackgroundColor = .windowBackgroundColor // avoid a white flash before styles.css loads
        webView.navigationDelegate = context.coordinator
        bridge.webView = webView
        webView.loadFileURL(WebCoreLocator.indexURL, allowingReadAccessTo: WebCoreLocator.directoryURL)
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        // Content pushes happen imperatively through `bridge`, driven by AppState —
        // there is no declarative state here to diff.
    }

    func makeCoordinator() -> Coordinator { Coordinator(onReady: onReady) }

    final class Coordinator: NSObject, WKNavigationDelegate {
        let onReady: () -> Void
        init(onReady: @escaping () -> Void) { self.onReady = onReady }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            onReady()
        }
    }
}
