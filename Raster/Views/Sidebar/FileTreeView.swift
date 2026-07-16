import SwiftUI

private struct FlatNode: Identifiable {
    let node: FileNode
    let depth: Int
    var id: URL { node.url }
}

/// The folder tree in the Files sidebar tab.
struct FileTreeView: View {
    @EnvironmentObject private var appState: AppState
    let colors: RasterColors
    let root: FileNode

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 1) {
                ForEach(flattened) { row in
                    rowView(row)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var flattened: [FlatNode] {
        var rows: [FlatNode] = []
        func walk(_ node: FileNode, depth: Int) {
            rows.append(FlatNode(node: node, depth: depth))
            if node.isDirectory, appState.expandedDirectoryURLs.contains(node.url) {
                for child in node.children ?? [] { walk(child, depth: depth + 1) }
            }
        }
        for child in root.children ?? [] { walk(child, depth: 0) }
        return rows
    }

    private func rowView(_ row: FlatNode) -> some View {
        let node = row.node
        let isActive = appState.activeDocument?.url == node.url
        let isSelected = appState.selectedNodeURLs.contains(node.url)
        let isExpanded = appState.expandedDirectoryURLs.contains(node.url)

        return HStack(spacing: 6) {
            Text(node.isDirectory ? "▶" : "")
                .font(.system(size: 8.5))
                .foregroundStyle(colors.dim)
                .frame(width: 10)
                .rotationEffect(.degrees(node.isDirectory && isExpanded ? 90 : 0))
            Text(node.isDirectory ? "▣" : "▤")
                .font(.system(size: 11))
                .foregroundStyle(node.isDirectory ? colors.dim : (isActive ? colors.accent : colors.dim))
            Text(node.name)
                .font(.system(size: 12.5))
                .foregroundStyle(isActive ? colors.inkStrong : colors.ink)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
        }
        .padding(.leading, 8 + CGFloat(row.depth) * 14)
        .padding(.trailing, 8)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 6).fill(isActive ? colors.accentSoft : (isSelected ? colors.hover : .clear)))
        .contentShape(Rectangle())
        .onTapGesture { handleTap(node) }
        .contextMenu {
            if !node.isDirectory {
                Button(String(localized: "Open")) {
                    Task { await appState.openDocument(at: node.url) }
                }
            }
            Button(String(localized: "Export as ZIP…")) {
                appState.openZipSheet(scope: zipScope(for: node))
            }
            Divider()
            Button(String(localized: "Reveal in Finder")) {
                NSWorkspace.shared.activateFileViewerSelecting([node.url])
            }
        }
    }

    /// Right-clicking inside the current multi-selection exports the whole
    /// selection; right-clicking outside it targets just that node.
    private func zipScope(for node: FileNode) -> [URL] {
        if appState.selectedNodeURLs.contains(node.url), appState.selectedNodeURLs.count > 1 {
            return Array(appState.selectedNodeURLs)
        }
        return [node.url]
    }

    private func handleTap(_ node: FileNode) {
        let isCommandClick = NSApp.currentEvent?.modifierFlags.contains(.command) ?? false
        if isCommandClick {
            if appState.selectedNodeURLs.contains(node.url) {
                appState.selectedNodeURLs.remove(node.url)
            } else {
                appState.selectedNodeURLs.insert(node.url)
            }
            return
        }
        if node.isDirectory {
            if appState.expandedDirectoryURLs.contains(node.url) {
                appState.expandedDirectoryURLs.remove(node.url)
            } else {
                appState.expandedDirectoryURLs.insert(node.url)
            }
            appState.selectedNodeURLs = [node.url]
        } else {
            appState.selectedNodeURLs = [node.url]
            Task { await appState.openDocument(at: node.url) }
        }
    }
}
