import SwiftUI

/// Mounts `MainWindowView` immediately (so the preview WebView starts loading
/// right away) and overlays `SplashView` on top until `AppState.isPreviewReady`
/// flips, then fades it out.
struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ZStack {
            MainWindowView()
            if !appState.isPreviewReady {
                SplashView()
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.35), value: appState.isPreviewReady)
    }
}
