import AppKit
import Foundation
import UniformTypeIdentifiers

/// Open/save panels, security-scoped bookmarks, and atomic file I/O.
/// Panel presentation runs on the main actor (NSOpenPanel/NSSavePanel are
/// modal AppKit UI); reads and writes hop off the main thread.
@MainActor
enum FileService {
    static func presentOpenFolderPanel() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = String(localized: "Open")
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func presentOpenFilePanel() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = markdownContentTypes
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func presentSavePanel(suggestedName: String) -> URL? {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedName
        panel.allowedContentTypes = markdownContentTypes
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func presentExportPanel(suggestedName: String, contentType: UTType) -> URL? {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedName
        panel.allowedContentTypes = [contentType]
        return panel.runModal() == .OK ? panel.url : nil
    }

    private static var markdownContentTypes: [UTType] {
        var types: [UTType] = [.plainText]
        if let md = UTType(filenameExtension: "md") { types.insert(md, at: 0) }
        if let markdown = UTType(filenameExtension: "markdown") { types.append(markdown) }
        return types
    }

    // MARK: - Security-scoped bookmarks

    static func makeBookmark(for url: URL) throws -> Data {
        do {
            return try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
        } catch {
            throw RasterError.bookmarkResolutionFailed
        }
    }

    static func resolveBookmark(_ data: Data) throws -> (url: URL, isStale: Bool) {
        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: data,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            return (url, isStale)
        } catch {
            throw RasterError.bookmarkResolutionFailed
        }
    }

    // MARK: - I/O

    static func readFile(at url: URL) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            do {
                return try String(contentsOf: url, encoding: .utf8)
            } catch {
                throw RasterError.fileReadFailed(url)
            }
        }.value
    }

    static func write(_ content: String, to url: URL) async throws {
        try await Task.detached(priority: .userInitiated) {
            do {
                try Data(content.utf8).write(to: url, options: .atomic)
            } catch {
                throw RasterError.fileWriteFailed(url)
            }
        }.value
    }
}
