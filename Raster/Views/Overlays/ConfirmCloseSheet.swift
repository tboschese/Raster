import SwiftUI

/// "Discard unsaved changes?" — shown when closing a dirty tab.
struct ConfirmCloseSheet: View {
    @EnvironmentObject private var appState: AppState
    let colors: RasterColors
    let documentName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Discard unsaved changes?")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(colors.inkStrong)
                .padding(.bottom, 6)

            Text(String(format: String(localized: "“%@” has unsaved changes. Your edits will be lost."), documentName))
                .font(.system(size: 12.5))
                .foregroundStyle(colors.dim)
                .padding(.bottom, 18)

            HStack {
                Spacer()
                Button(String(localized: "Cancel")) { appState.cancelClose() }
                    .buttonStyle(.bordered)
                Button(String(localized: "Discard")) { appState.discardAndClose() }
                    .buttonStyle(.bordered)
                    .tint(colors.danger)
                Button(String(localized: "Save")) { Task { await appState.saveAndClose() } }
                    .buttonStyle(.borderedProminent)
                    .tint(colors.accent)
            }
        }
        .padding(22)
        .frame(width: 360)
        .background(colors.panel)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(colors.border, lineWidth: 1))
        .shadow(color: .black.opacity(0.5), radius: 24, y: 12)
    }
}
