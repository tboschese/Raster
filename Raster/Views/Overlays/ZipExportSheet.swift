import SwiftUI

/// Options sheet shown before the ZIP save panel — preserve structure /
/// include rendered HTML, per CLAUDE.md "Export (PDF & ZIP)".
struct ZipExportSheet: View {
    @EnvironmentObject private var appState: AppState
    let colors: RasterColors

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Export as ZIP")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(colors.inkStrong)
                .padding(.bottom, 4)

            Text(scopeText)
                .font(.system(size: 11.5, design: .monospaced))
                .foregroundStyle(colors.dim)
                .padding(.bottom, 16)

            Toggle(isOn: $appState.zipOptions.preserveStructure) {
                Text("Preserve folder structure").font(.system(size: 12.5)).foregroundStyle(colors.ink)
            }
            .toggleStyle(.checkbox)
            .padding(.bottom, 10)

            Toggle(isOn: $appState.zipOptions.includeRenderedHTML) {
                Text("Include rendered HTML").font(.system(size: 12.5)).foregroundStyle(colors.ink)
            }
            .toggleStyle(.checkbox)
            .padding(.bottom, 20)

            HStack {
                Spacer()
                Button(String(localized: "Cancel")) { appState.isZipSheetPresented = false }
                    .buttonStyle(.bordered)
                Button(String(localized: "Export")) { Task { await appState.confirmZipExport() } }
                    .buttonStyle(.borderedProminent)
                    .tint(colors.accent)
            }
        }
        .padding(22)
        .frame(width: 390)
        .background(colors.panel)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(colors.border, lineWidth: 1))
        .shadow(color: .black.opacity(0.5), radius: 24, y: 12)
    }

    private var scopeText: String {
        String(format: String(localized: "%lld item(s) selected"), appState.zipScopeURLs.count)
    }
}
