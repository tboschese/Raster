import SwiftUI

/// VS Code-style tabs: dirty dot, close button, click to switch, horizontal scroll.
struct TabBarView: View {
    @EnvironmentObject private var appState: AppState
    let colors: RasterColors

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(appState.openDocuments) { document in
                    tab(for: document)
                }
                Spacer(minLength: 0)
            }
        }
        .frame(height: 35)
        .background(colors.panel)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(colors.border), alignment: .bottom)
    }

    private func tab(for document: MarkdownDocument) -> some View {
        let isActive = document.id == appState.activeDocumentID
        return HStack(spacing: 7) {
            Text("▤").font(.system(size: 10.5)).foregroundStyle(colors.dim)
            Text(document.name)
                .font(.system(size: 12))
                .foregroundStyle(isActive ? colors.inkStrong : colors.dim)
                .lineLimit(1)
                .truncationMode(.tail)
            if document.isDirty {
                Circle().fill(colors.accent).frame(width: 7, height: 7)
            }
            Button {
                appState.requestClose(document.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(colors.dim)
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 12)
        .padding(.trailing, 10)
        .frame(maxWidth: 200)
        .frame(maxHeight: .infinity)
        .background(isActive ? colors.editorBackground : Color.clear)
        .overlay(alignment: .top) {
            if isActive {
                Rectangle().fill(colors.accent).frame(height: 2)
            }
        }
        .overlay(alignment: .trailing) {
            Rectangle().fill(colors.border).frame(width: 1)
        }
        .contentShape(Rectangle())
        .onTapGesture { appState.setActiveDocument(document.id) }
    }
}
