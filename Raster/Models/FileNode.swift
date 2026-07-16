import Foundation

/// One node in the workspace's folder tree.
struct FileNode: Identifiable, Equatable {
    enum Kind: Equatable {
        case directory
        case file
    }

    let url: URL
    let kind: Kind
    var children: [FileNode]?

    var id: URL { url }
    var name: String { url.lastPathComponent }
    var isDirectory: Bool { kind == .directory }

    static let markdownExtensions: Set<String> = ["md", "markdown", "txt"]

    /// Builds a tree rooted at `url`, recursing into directories. Skips hidden
    /// files/folders and anything that isn't a directory or a Markdown/text file.
    static func buildTree(at url: URL, fileManager: FileManager = .default) -> FileNode {
        var isDir: ObjCBool = false
        fileManager.fileExists(atPath: url.path, isDirectory: &isDir)
        guard isDir.boolValue else {
            return FileNode(url: url, kind: .file, children: nil)
        }
        let contents = (try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        let children = contents
            .filter { candidate in
                let values = try? candidate.resourceValues(forKeys: [.isDirectoryKey])
                let isDirectory = values?.isDirectory ?? false
                return isDirectory || markdownExtensions.contains(candidate.pathExtension.lowercased())
            }
            .sorted { lhs, rhs in
                let lhsIsDir = (try? lhs.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                let rhsIsDir = (try? rhs.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                if lhsIsDir != rhsIsDir { return lhsIsDir }
                return lhs.lastPathComponent.localizedStandardCompare(rhs.lastPathComponent) == .orderedAscending
            }
            .map { buildTree(at: $0, fileManager: fileManager) }
        return FileNode(url: url, kind: .directory, children: children)
    }
}
