import SwiftUI

/// Theme / reading font / language override — persisted via `PreferencesStore`.
struct PreferencesView: View {
    @EnvironmentObject private var appState: AppState
    let colors: RasterColors

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Preferences")
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(colors.inkStrong)
                Spacer()
                Button {
                    appState.isPreferencesPresented = false
                } label: {
                    Image(systemName: "xmark").font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundStyle(colors.dim)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .overlay(Rectangle().fill(colors.border).frame(height: 1), alignment: .bottom)

            VStack(spacing: 16) {
                row(String(localized: "Theme")) {
                    Picker("", selection: $appState.theme) {
                        Text("Dark").tag(Theme.dark)
                        Text("Light").tag(Theme.light)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 140)
                }
                row(String(localized: "Reading font")) {
                    Picker("", selection: $appState.readingFont) {
                        Text("Serif").tag(ReadingFont.serif)
                        Text("Sans").tag(ReadingFont.sans)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 140)
                }
                row(String(localized: "Language")) {
                    Picker("", selection: $appState.language) {
                        Text("System").tag(AppLanguage.system)
                        Text("English").tag(AppLanguage.en)
                        Text("Português (Brasil)").tag(AppLanguage.ptBR)
                    }
                    .pickerStyle(.menu)
                    .frame(width: 160)
                }
            }
            .padding(20)
        }
        .frame(width: 400)
        .background(colors.panel)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(colors.border, lineWidth: 1))
        .shadow(color: .black.opacity(0.5), radius: 24, y: 12)
    }

    private func row(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        HStack {
            Text(title).font(.system(size: 12.5)).foregroundStyle(colors.ink)
            Spacer()
            content()
        }
    }
}
