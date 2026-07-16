import SwiftUI

/// Table of contents with scroll-spy highlighting (`didChangeActiveHeading`).
struct OutlineView: View {
    @EnvironmentObject private var appState: AppState
    let colors: RasterColors

    var body: some View {
        if appState.outline.isEmpty {
            Text("No headings.")
                .font(.system(size: 12))
                .foregroundStyle(colors.dim)
                .padding(8)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(appState.outline) { entry in
                        row(entry)
                    }
                }
            }
        }
    }

    private func row(_ entry: OutlineEntry) -> some View {
        let isActive = appState.activeHeadingID == entry.id
        return Text(entry.title)
            .font(.system(size: entry.level == 1 ? 12.5 : 12, weight: entry.level == 1 ? .semibold : .regular))
            .foregroundStyle(isActive ? colors.accent : (entry.level == 1 ? colors.inkStrong : colors.dim))
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 10 + CGFloat(entry.level - 1) * 13)
            .padding(.trailing, 8)
            .padding(.vertical, 4)
            .background(isActive ? colors.accentSoft : .clear)
            .overlay(alignment: .leading) {
                Rectangle().fill(isActive ? colors.accent : .clear).frame(width: 2)
            }
            .contentShape(Rectangle())
            .onTapGesture { appState.scrollToHeading(entry.id) }
    }
}
