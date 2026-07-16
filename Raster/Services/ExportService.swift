import AppKit
import Foundation
import ZIPFoundation

struct ZipExportOptions {
    var preserveStructure: Bool = true
    var includeRenderedHTML: Bool = false
}

struct ZipExportItem {
    /// Path relative to the workspace root, e.g. `"docs/architecture.md"`.
    let relativePath: String
    let sourceURL: URL
}

struct ZipExportSummary {
    var exportedCount: Int
    var skipped: [(name: String, reason: String)]
}

/// HTML, PDF, and ZIP export. PDF and HTML both render through the same
/// WebCore engine as the live preview (via `OffscreenRenderer`) so exported
/// output is pixel-for-pixel what the app renders — see CLAUDE.md "Export".
@MainActor
enum ExportService {
    // MARK: - HTML

    static func exportHTML(markdown: String, title: String, language: String, to destinationURL: URL) async throws {
        let renderer = OffscreenRenderer()
        try await renderer.prepare(frame: CGRect(x: 0, y: 0, width: 900, height: 1200))
        let html = try await htmlDocument(markdown: markdown, title: title, language: language, renderer: renderer)
        try await FileService.write(html, to: destinationURL)
    }

    /// Renders one document to a standalone HTML string through an already
    /// prepared renderer, so batch callers (ZIP export) pay the WebView
    /// startup cost once instead of per file.
    private static func htmlDocument(
        markdown: String,
        title: String,
        language: String,
        renderer: OffscreenRenderer
    ) async throws -> String {
        try await renderer.renderForPrint(markdown: markdown, language: language)
        guard let webView = renderer.webView else {
            throw RasterError.exportFailed("Couldn't prepare the export renderer.")
        }
        let bodyHTML = (try? await webView.evaluateJavaScript("document.getElementById('doc').innerHTML")) as? String ?? ""
        let cssURL = WebCoreLocator.directoryURL.appendingPathComponent("styles.css")
        let css = (try? String(contentsOf: cssURL, encoding: .utf8)) ?? ""
        return """
        <!DOCTYPE html>
        <html lang="\(language)" data-theme="light" data-mode="print">
        <head>
        <meta charset="utf-8">
        <title>\(escapeHTML(title))</title>
        <style>\(css)</style>
        </head>
        <body>
        <div class="md-doc-wrap"><div class="md-doc">\(bodyHTML)</div></div>
        </body>
        </html>
        """
    }

    // MARK: - PDF (print-operation path — NOT WKWebView.createPDF, see CLAUDE.md)

    static func exportPDF(markdown: String, language: String, to destinationURL: URL) async throws {
        let basePrintInfo = NSPrintInfo.shared
        let paperSize = basePrintInfo.paperSize
        let renderer = OffscreenRenderer()
        try await renderer.prepare(frame: CGRect(origin: .zero, size: paperSize))
        try await renderer.renderForPrint(markdown: markdown, language: language)
        guard let webView = renderer.webView else {
            throw RasterError.exportFailed("Couldn't prepare the export renderer.")
        }

        let printInfo = NSPrintInfo(dictionary: basePrintInfo.dictionary() as? [NSPrintInfo.AttributeKey: Any] ?? [:])
        printInfo.jobDisposition = .save
        printInfo.dictionary()[NSPrintInfo.AttributeKey.jobSavingURL] = destinationURL
        printInfo.horizontalPagination = .automatic
        printInfo.verticalPagination = .automatic
        printInfo.isHorizontallyCentered = false
        printInfo.isVerticallyCentered = false

        let operation = webView.printOperation(with: printInfo)
        operation.showsPrintPanel = false
        operation.showsProgressPanel = false

        guard operation.run() else {
            throw RasterError.exportFailed("The print operation didn't complete.")
        }
    }

    /// File → Print… (⌘P): a normal print path with the native panel — the
    /// user picks a printer or "Save as PDF" themselves. Distinct from
    /// `exportPDF`, which is the panel-less, first-class PDF export.
    static func printDocument(markdown: String, language: String) async throws {
        let renderer = OffscreenRenderer()
        let paperSize = NSPrintInfo.shared.paperSize
        try await renderer.prepare(frame: CGRect(origin: .zero, size: paperSize))
        try await renderer.renderForPrint(markdown: markdown, language: language)
        guard let webView = renderer.webView else {
            throw RasterError.exportFailed("Couldn't prepare the print renderer.")
        }
        let operation = webView.printOperation(with: .shared)
        operation.showsPrintPanel = true
        operation.showsProgressPanel = true
        _ = operation.run()
    }

    // MARK: - ZIP

    static func exportZIP(
        items: [ZipExportItem],
        options: ZipExportOptions,
        language: String,
        to destinationURL: URL
    ) async throws -> ZipExportSummary {
        let archive: Archive
        do {
            archive = try Archive(url: destinationURL, accessMode: .create)
        } catch {
            throw RasterError.exportFailed("Couldn't create the archive.")
        }

        var exported = 0
        var skipped: [(String, String)] = []
        var usedFlatNames: Set<String> = []

        // One shared renderer for the whole batch — preparing a WKWebView per
        // file would dominate the export time for large folders.
        var htmlRenderer: OffscreenRenderer?
        if options.includeRenderedHTML {
            let renderer = OffscreenRenderer()
            try await renderer.prepare(frame: CGRect(x: 0, y: 0, width: 900, height: 1200))
            htmlRenderer = renderer
        }

        for item in items {
            do {
                let markdown = try await FileService.readFile(at: item.sourceURL)
                let entryPath = options.preserveStructure
                    ? item.relativePath
                    : uniqueFlatName(for: item.relativePath, used: &usedFlatNames)
                try addTextEntry(markdown, path: entryPath, to: archive)
                exported += 1

                if let htmlRenderer {
                    let title = (item.relativePath as NSString).lastPathComponent
                    let htmlPath = (entryPath as NSString).deletingPathExtension + ".html"
                    let html = try await htmlDocument(markdown: markdown, title: title, language: language, renderer: htmlRenderer)
                    try addTextEntry(html, path: htmlPath, to: archive)
                }
            } catch {
                skipped.append((item.relativePath, error.localizedDescription))
            }
        }

        return ZipExportSummary(exportedCount: exported, skipped: skipped)
    }

    private static func addTextEntry(_ text: String, path: String, to archive: Archive) throws {
        let data = Data(text.utf8)
        try archive.addEntry(with: path, type: .file, uncompressedSize: Int64(data.count)) { position, size -> Data in
            let start = Int(position)
            let end = min(start + size, data.count)
            return data.subdata(in: start..<end)
        }
    }

    private static func uniqueFlatName(for relativePath: String, used: inout Set<String>) -> String {
        let base = (relativePath as NSString).lastPathComponent
        let ext = (base as NSString).pathExtension
        let stem = (base as NSString).deletingPathExtension
        var candidate = base
        var suffix = 1
        while used.contains(candidate) {
            candidate = ext.isEmpty ? "\(stem)-\(suffix)" : "\(stem)-\(suffix).\(ext)"
            suffix += 1
        }
        used.insert(candidate)
        return candidate
    }

    private static func escapeHTML(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
