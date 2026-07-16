import SwiftUI

/// The floating find bar shown over the preview pane (⌘F).
struct FindBar: View {
    @EnvironmentObject private var appState: AppState
    let colors: RasterColors
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 6) {
            TextField(String(localized: "Find in document"), text: Binding(
                get: { appState.findQuery },
                set: { appState.setFindQuery($0) }
            ))
            .textFieldStyle(.plain)
            .font(.system(size: 12))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(width: 170)
            .background(RoundedRectangle(cornerRadius: 5).fill(colors.bg))
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(colors.border, lineWidth: 1))
            .focused($isFocused)
            .onSubmit { appState.findStep(1) }

            Text(counterText)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(colors.dim)
                .frame(minWidth: 34)

            Button { appState.findStep(-1) } label: {
                Image(systemName: "chevron.up").font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .foregroundStyle(colors.dim)

            Button { appState.findStep(1) } label: {
                Image(systemName: "chevron.down").font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .foregroundStyle(colors.dim)

            Button { appState.closeFind() } label: {
                Image(systemName: "xmark").font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .foregroundStyle(colors.dim)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 8).fill(colors.panel))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(colors.border, lineWidth: 1))
        .shadow(color: .black.opacity(0.3), radius: 12, y: 6)
        .onAppear { isFocused = true }
    }

    private var counterText: String {
        guard !appState.findQuery.isEmpty else { return "" }
        guard let result = appState.findResult, result.total > 0 else { return "0/0" }
        return "\(result.current)/\(result.total)"
    }
}
