import SwiftUI

/// The sidebar's Files/Outline segmented switch plus whichever pane is active.
struct ExplorerView: View {
    @EnvironmentObject private var appState: AppState
    let colors: RasterColors

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                segment(.files, title: String(localized: "Files"))
                segment(.outline, title: String(localized: "Outline"))
            }
            .padding(2)
            .background(RoundedRectangle(cornerRadius: 7).fill(colors.bg))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(colors.border, lineWidth: 1))
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 8)

            if appState.sidebarTab == .files {
                if let workspace = appState.workspace {
                    Text(workspace.name.uppercased())
                        .font(.system(size: 10.5, design: .monospaced))
                        .tracking(1.1)
                        .foregroundStyle(colors.dim)
                        .padding(.horizontal, 18)
                        .padding(.bottom, 7)
                    FileTreeView(colors: colors, root: workspace.rootNode)
                } else {
                    Text("No folder open.")
                        .font(.system(size: 12))
                        .foregroundStyle(colors.dim)
                        .padding(12)
                }
            } else {
                OutlineView(colors: colors)
            }
        }
        .frame(width: 242)
        .background(colors.side)
    }

    private func segment(_ tab: SidebarTab, title: String) -> some View {
        Button {
            appState.sidebarTab = tab
        } label: {
            Text(title)
                .font(.system(size: 11.5, weight: appState.sidebarTab == tab ? .semibold : .regular))
                .foregroundStyle(appState.sidebarTab == tab ? colors.inkStrong : colors.dim)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 3.5)
                .background(RoundedRectangle(cornerRadius: 5).fill(appState.sidebarTab == tab ? colors.panel : .clear))
        }
        .buttonStyle(.plain)
    }
}
