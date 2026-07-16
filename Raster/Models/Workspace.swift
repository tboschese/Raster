import Foundation

/// An opened folder: its security-scoped bookmark, root URL, and file tree.
/// Security-scoped access is started when the workspace is created/reopened
/// and must be paired with `stopAccessing()` when it's replaced or the app quits.
struct Workspace: Identifiable {
    let id = UUID()
    let rootURL: URL
    var rootNode: FileNode
    var bookmarkData: Data?

    private var isAccessingSecurityScope = false

    init(rootURL: URL, bookmarkData: Data? = nil) {
        self.rootURL = rootURL
        self.bookmarkData = bookmarkData
        self.rootNode = FileNode(url: rootURL, kind: .directory, children: [])
    }

    var name: String { rootURL.lastPathComponent }

    mutating func reloadTree(fileManager: FileManager = .default) {
        rootNode = FileNode.buildTree(at: rootURL, fileManager: fileManager)
    }

    @discardableResult
    mutating func startAccessing() -> Bool {
        guard !isAccessingSecurityScope else { return true }
        isAccessingSecurityScope = rootURL.startAccessingSecurityScopedResource()
        return isAccessingSecurityScope
    }

    mutating func stopAccessing() {
        guard isAccessingSecurityScope else { return }
        rootURL.stopAccessingSecurityScopedResource()
        isAccessingSecurityScope = false
    }
}
