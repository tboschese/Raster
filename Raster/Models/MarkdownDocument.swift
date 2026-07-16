import Foundation

/// A single open Markdown document. `content` is the single source of truth —
/// both the source editor and the preview WebView derive from it.
struct MarkdownDocument: Identifiable, Equatable {
    let id: UUID
    var url: URL?
    var name: String
    var content: String
    var bookmarkData: Data?

    private var savedContent: String

    var isDirty: Bool { content != savedContent }

    init(id: UUID = UUID(), url: URL? = nil, name: String, content: String = "", bookmarkData: Data? = nil) {
        self.id = id
        self.url = url
        self.name = name
        self.content = content
        self.savedContent = content
        self.bookmarkData = bookmarkData
    }

    mutating func markSaved() {
        savedContent = content
    }

    mutating func revertToSaved() {
        content = savedContent
    }
}
