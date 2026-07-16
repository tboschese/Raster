import SwiftUI

/// Top-level layout: toolbar | sidebar + (tabs + panes) | status bar, plus
/// the overlay stack (find bar, zip sheet, confirm-close, preferences, toast).
struct MainWindowView: View {
    @EnvironmentObject private var appState: AppState

    private var colors: RasterColors { appState.theme.colors }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            HStack(spacing: 0) {
                if appState.explorerVisible {
                    ExplorerView(colors: colors)
                    Rectangle().fill(colors.border).frame(width: 1)
                }
                contentColumn
            }
        }
        .background(colors.bg)
        .overlay(overlayStack)
        .onAppear { Task { await bootstrapIfNeeded() } }
        .alert(item: Binding(
            get: { appState.lastError.map(ErrorBox.init) },
            set: { _ in appState.lastError = nil }
        )) { box in
            Alert(title: Text("Raster"), message: Text(box.error.errorDescription ?? ""))
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 10) {
            Color.clear.frame(width: 68, height: 1) // reserved for the real traffic lights (hiddenTitleBar)

            toolbarIconButton(systemName: "sidebar.left", isActive: appState.explorerVisible) {
                appState.explorerVisible.toggle()
            }
            .help(String(localized: "Toggle explorer  ⌘\\"))

            brandMark

            ModeSwitch(mode: $appState.mode, colors: colors)
                .padding(.leading, 6)

            Rectangle().fill(colors.border).frame(width: 1, height: 18).padding(.horizontal, 4)

            FormatToolbar(colors: colors, isEnabled: appState.activeDocument != nil) { command in
                appState.applyFormat(command)
            }

            Spacer()

            toolbarIconButton(systemName: "magnifyingglass", isActive: appState.isFindOpen) {
                if appState.isFindOpen { appState.closeFind() } else { appState.openFind() }
            }
            .help(String(localized: "Find  ⌘F"))
            .disabled(appState.mode == .editor)
            .opacity(appState.mode == .editor ? 0.4 : 1)

            toolbarIconButton(systemName: appState.readingFont == .serif ? "textformat" : "textformat.abc", isActive: false) {
                appState.readingFont = appState.readingFont == .serif ? .sans : .serif
            }
            .help(String(localized: "Reading font"))

            toolbarIconButton(systemName: appState.theme == .dark ? "circle.lefthalf.filled" : "circle.righthalf.filled", isActive: false) {
                appState.theme = appState.theme == .dark ? .light : .dark
            }
            .help(String(localized: "Theme"))
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
        .background(WindowDragArea()) // empty toolbar areas drag the window; double-click zooms (hiddenTitleBar has no real title bar)
        .background(colors.panel)
        .overlay(Rectangle().fill(colors.border).frame(height: 1), alignment: .bottom)
        .zIndex(30)
    }

    private var brandMark: some View {
        Image("LogoMark")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(height: 15)
    }

    private func toolbarIconButton(systemName: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13))
                .foregroundStyle(isActive ? colors.accent : colors.dim)
                .frame(width: 28, height: 26)
                .background(RoundedRectangle(cornerRadius: 6).fill(isActive ? colors.accentSoft : .clear))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Content column

    private var contentColumn: some View {
        VStack(spacing: 0) {
            TabBarView(colors: colors)
            ZStack {
                if appState.openDocuments.isEmpty {
                    emptyState
                } else {
                    panes
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            StatusBarView(colors: colors)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Text("▤").font(.system(size: 26)).foregroundStyle(colors.dim.opacity(0.5))
            Text("Open a file").font(.system(size: 13)).foregroundStyle(colors.dim)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(colors.editorBackground)
    }

    private var panes: some View {
        HStack(spacing: 0) {
            if appState.mode == .editor || appState.mode == .split {
                SourceEditor(
                    text: Binding(
                        get: { appState.activeDocument?.content ?? "" },
                        set: { appState.updateActiveContent($0) }
                    ),
                    theme: appState.theme,
                    pendingSelection: appState.pendingSelection,
                    onSelectionChange: { appState.updateSelection($0) },
                    onCursorPositionChange: { appState.updateCursorPosition(line: $0, column: $1) },
                    onConsumePendingSelection: { appState.pendingSelection = nil }
                )
                .background(colors.editorBackground)
            }

            if appState.mode == .split {
                Rectangle().fill(colors.border).frame(width: 1)
            }

            // The preview stays mounted in Editor mode (width 0) so the
            // WKWebView never reloads on mode switches and the outline keeps
            // updating from the engine even while the preview is hidden.
            ZStack(alignment: .topTrailing) {
                PreviewWebView(bridge: appState.bridge) { appState.previewDidLoad() }

                if appState.mode == .reading {
                    readEditToggle
                        .padding(.top, appState.isReadingEditing ? 38 : 14)
                        .padding(.trailing, 18)
                }

                if appState.isFindOpen {
                    FindBar(colors: colors)
                        .padding(.top, findBarTopOffset)
                        .padding(.trailing, 18)
                }
            }
            .frame(maxWidth: appState.mode == .editor ? 0 : .infinity)
            .clipped()
            .allowsHitTesting(appState.mode != .editor)
        }
    }

    private var findBarTopOffset: CGFloat {
        guard appState.mode == .reading else { return 14 }
        return appState.isReadingEditing ? 76 : 52
    }

    private var readEditToggle: some View {
        HStack(spacing: 0) {
            Button(String(localized: "Read")) {
                if appState.isReadingEditing { appState.toggleReadEdit() }
            }
            .buttonStyle(.plain)
            .font(.system(size: 11.5, weight: appState.isReadingEditing ? .regular : .semibold))
            .foregroundStyle(appState.isReadingEditing ? colors.dim : colors.inkStrong)
            .padding(.horizontal, 12)
            .padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 5).fill(appState.isReadingEditing ? .clear : colors.panel))

            Button(String(localized: "Edit")) {
                if !appState.isReadingEditing { appState.toggleReadEdit() }
            }
            .buttonStyle(.plain)
            .font(.system(size: 11.5, weight: appState.isReadingEditing ? .semibold : .regular))
            .foregroundStyle(appState.isReadingEditing ? colors.accent : colors.dim)
            .padding(.horizontal, 12)
            .padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 5).fill(appState.isReadingEditing ? colors.accentSoft : .clear))
        }
        .padding(2)
        .background(RoundedRectangle(cornerRadius: 7).fill(colors.panel))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(colors.border, lineWidth: 1))
        .shadow(color: .black.opacity(0.25), radius: 14, y: 4)
    }

    // MARK: - Overlays

    @ViewBuilder
    private var overlayStack: some View {
        ZStack {
            if let pendingID = appState.pendingCloseDocumentID,
               let document = appState.openDocuments.first(where: { $0.id == pendingID }) {
                dimmedOverlay {
                    ConfirmCloseSheet(colors: colors, documentName: appState.baseName(document.name))
                }
            }
            if appState.isZipSheetPresented {
                dimmedOverlay {
                    ZipExportSheet(colors: colors)
                }
            }
            if appState.isPreferencesPresented {
                dimmedOverlay {
                    PreferencesView(colors: colors)
                }
            }
            if let message = appState.toastMessage {
                VStack {
                    Spacer()
                    ToastView(colors: colors, message: message)
                        .padding(.bottom, 44)
                }
                .animation(.easeOut(duration: 0.18), value: appState.toastMessage)
            }
        }
    }

    private func dimmedOverlay(@ViewBuilder content: () -> some View) -> some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack {
                content().padding(.top, 70)
                Spacer()
            }
        }
    }

    private func bootstrapIfNeeded() async {
        guard appState.openDocuments.isEmpty else { return }
        let bcp47 = LocalizationService.resolvedBCP47(for: appState.language)
        let sampleName = bcp47 == "pt-BR" ? "sample.pt-BR" : "sample.en"
        guard let url = Bundle.main.url(forResource: sampleName, withExtension: "md", subdirectory: "WebCore"),
              let content = try? String(contentsOf: url, encoding: .utf8) else { return }
        appState.openSampleDocument(name: sampleName.replacingOccurrences(of: "sample.", with: "") + ".md", content: content)
    }
}

private struct ErrorBox: Identifiable {
    let error: RasterError
    var id: String { error.localizedDescription }
}
