import SwiftUI

/// Launch splash — the logo mark, shown briefly while the preview WebView
/// loads. Per CLAUDE.md, branding lives only in the name and the logo, never
/// on the reading surface itself — this is pre-content chrome only, and
/// disappears the moment the app is ready to read. Follows the app theme so
/// it doesn't flash a mismatched background on hand-off to the real window.
struct SplashView: View {
    @EnvironmentObject private var appState: AppState
    private var colors: RasterColors { appState.theme.colors }

    var body: some View {
        ZStack {
            colors.bg.ignoresSafeArea()
            VStack(spacing: 14) {
                Image("LogoMark")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 240)
                Text("Markdown Editor")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .tracking(3)
                    .foregroundStyle(colors.dim)
            }
        }
    }
}
