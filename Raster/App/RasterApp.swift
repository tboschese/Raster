import SwiftUI

@main
struct RasterApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .frame(minWidth: 860, minHeight: 560)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button(String(localized: "New File")) { appState.newFile() }
                    .keyboardShortcut("n", modifiers: .command)
                Button(String(localized: "Open File…")) { Task { await appState.openFilePanel() } }
                    .keyboardShortcut("o", modifiers: .command)
                Button(String(localized: "Open Folder…")) { Task { await appState.openFolderPanel() } }
                    .keyboardShortcut("o", modifiers: [.command, .shift])
            }
            CommandGroup(replacing: .saveItem) {
                Button(String(localized: "Save")) { Task { await appState.save() } }
                    .keyboardShortcut("s", modifiers: .command)
                    .disabled(appState.activeDocument == nil)
                Divider()
                Button(String(localized: "Close Tab")) {
                    if let id = appState.activeDocumentID { appState.requestClose(id) }
                }
                .keyboardShortcut("w", modifiers: .command)
                .disabled(appState.activeDocumentID == nil)
            }
            CommandGroup(after: .saveItem) {
                Divider()
                Button(String(localized: "Export HTML…")) { Task { await appState.exportActiveHTML() } }
                    .disabled(appState.activeDocument == nil)
                Button(String(localized: "Export PDF…")) { Task { await appState.exportActivePDF() } }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
                    .disabled(appState.activeDocument == nil)
                Button(String(localized: "Export as ZIP…")) {
                    let scope = appState.selectedNodeURLs.isEmpty
                        ? (appState.workspace.map { [$0.rootURL] } ?? [])
                        : Array(appState.selectedNodeURLs)
                    appState.openZipSheet(scope: scope)
                }
                .disabled(appState.workspace == nil)
            }
            CommandGroup(replacing: .printItem) {
                Button(String(localized: "Print…")) { Task { await appState.printActiveDocument() } }
                    .keyboardShortcut("p", modifiers: .command)
                    .disabled(appState.activeDocument == nil)
            }
            CommandGroup(replacing: .appSettings) {
                Button(String(localized: "Preferences…")) { appState.isPreferencesPresented = true }
                    .keyboardShortcut(",", modifiers: .command)
            }
            CommandMenu(String(localized: "Format")) {
                ForEach(FormatCommand.allCases) { command in
                    Button(command.menuTitle) { appState.applyFormat(command) }
                        .withOptionalShortcut(command.shortcut)
                }
            }
            CommandGroup(after: .toolbar) {
                Divider()
                Button(String(localized: "Toggle Explorer")) { appState.explorerVisible.toggle() }
                    .keyboardShortcut("\\", modifiers: .command)
                Divider()
                Button(String(localized: "Editor")) { appState.mode = .editor }
                    .keyboardShortcut("1", modifiers: .command)
                Button(String(localized: "Split")) { appState.mode = .split }
                    .keyboardShortcut("2", modifiers: .command)
                Button(String(localized: "Reading")) { appState.mode = .reading }
                    .keyboardShortcut("3", modifiers: .command)
                Button(String(localized: "Toggle Read / Edit")) { appState.toggleReadEdit() }
                    .keyboardShortcut("e", modifiers: .command)
                    .disabled(appState.mode != .reading)
                Divider()
                Button(String(localized: "Find")) { appState.openFind() }
                    .keyboardShortcut("f", modifiers: .command)
                    .disabled(appState.mode == .editor)
            }
        }
    }
}

private extension View {
    @ViewBuilder
    func withOptionalShortcut(_ shortcut: (key: KeyEquivalent, modifiers: EventModifiers)?) -> some View {
        if let shortcut {
            self.keyboardShortcut(shortcut.key, modifiers: shortcut.modifiers)
        } else {
            self
        }
    }
}

private extension FormatCommand {
    var menuTitle: String {
        switch self {
        case .bold: return String(localized: "Bold")
        case .italic: return String(localized: "Italic")
        case .strikethrough: return String(localized: "Strikethrough")
        case .heading: return String(localized: "Heading")
        case .link: return String(localized: "Link")
        case .list: return String(localized: "List")
        case .task: return String(localized: "Task List")
        case .quote: return String(localized: "Quote")
        case .codeBlock: return String(localized: "Code Block")
        case .table: return String(localized: "Table")
        }
    }

    var shortcut: (key: KeyEquivalent, modifiers: EventModifiers)? {
        switch self {
        case .bold: return ("b", .command)
        case .italic: return ("i", .command)
        case .link: return ("k", .command)
        default: return nil
        }
    }
}
