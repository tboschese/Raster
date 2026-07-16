import SwiftUI

/// Word count, reading time, and line/column — formatting happens here (via
/// the String Catalog), engine.js only ever sends raw numbers.
struct StatusBarView: View {
    @EnvironmentObject private var appState: AppState
    let colors: RasterColors

    var body: some View {
        HStack(spacing: 8) {
            Text("◆").foregroundStyle(colors.accent)
            Text("RASTER").tracking(1.2)
            separator
            Text(fileName)
            separator
            Text(statsText)
            Spacer()
            Text(positionText)
        }
        .font(.system(size: 10.5, design: .monospaced))
        .foregroundStyle(colors.dim)
        .padding(.horizontal, 14)
        .frame(height: 24)
        .background(colors.panel)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(colors.border), alignment: .top)
    }

    private var separator: some View {
        Text("·").opacity(0.45)
    }

    private var fileName: String {
        appState.activeDocument.map { appState.baseName($0.name) } ?? "—"
    }

    private var statsText: String {
        String(format: String(localized: "%lld words · %lld min"), appState.stats.words, appState.stats.readingMinutes)
    }

    private var positionText: String {
        String(format: String(localized: "Ln %lld, Col %lld"), appState.ln, appState.col)
    }
}
