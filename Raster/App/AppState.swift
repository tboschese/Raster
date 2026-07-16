import Foundation
import UniformTypeIdentifiers

/// Central app state. `openDocuments[].content` is the single source of truth —
/// the source editor and the preview WebView both derive from it (see
/// CLAUDE.md "Architecture"). All mutation goes through this object; views
/// only read it and call its methods.
@MainActor
final class AppState: ObservableObject {
    @Published var openDocuments: [MarkdownDocument] = []
    @Published var activeDocumentID: UUID?
    @Published var workspace: Workspace?
    @Published var mode: EditorMode = .split {
        didSet { if oldValue != mode { didChangeMode() } }
    }
    @Published var isReadingEditing = false
    @Published var theme: Theme = .dark {
        didSet { preferences.theme = theme; bridge.setTheme(theme) }
    }
    @Published var readingFont: ReadingFont = .serif {
        didSet { preferences.readingFont = readingFont; bridge.setReadingFont(readingFont) }
    }
    @Published var explorerVisible = true
    @Published var sidebarTab: SidebarTab = .files
    /// Drives the launch splash (`RootView`) — true once the preview WebView
    /// has loaded and the first document has been pushed to it.
    @Published var isPreviewReady = false
    @Published var language: AppLanguage = .system {
        didSet { preferences.language = language; bridge.setLanguage(LocalizationService.resolvedBCP47(for: language)) }
    }

    // Preview-derived state, pushed up from engine.js via WebBridge.
    @Published var outline: [OutlineEntry] = []
    @Published var activeHeadingID: String?
    @Published var stats = DocumentStats()

    // Find in document
    @Published var isFindOpen = false
    @Published var findQuery = ""
    @Published var findResult: FindResult?

    // Explorer selection
    @Published var selectedNodeURLs: Set<URL> = []
    @Published var expandedDirectoryURLs: Set<URL> = []

    // Overlays
    @Published var pendingCloseDocumentID: UUID?
    @Published var isZipSheetPresented = false
    @Published var zipScopeURLs: [URL] = []
    @Published var zipOptions = ZipExportOptions()
    @Published var isPreferencesPresented = false
    @Published var toastMessage: String?
    @Published var lastError: RasterError?

    @Published private(set) var ln = 1
    @Published private(set) var col = 1
    @Published var selection = NSRange(location: 0, length: 0)
    @Published var pendingSelection: NSRange?

    let bridge: WebBridge
    let preferences: PreferencesStore

    private var toastTask: Task<Void, Never>?
    private var renderDebounceTask: Task<Void, Never>?
    /// The document a WYSIWYG editing session belongs to. Commits arrive
    /// asynchronously from the WebView, so by the time `didEditMarkdown`
    /// lands the active tab may already have changed — the commit must be
    /// applied to the document that was being edited, not whichever is active.
    private var wysiwygTargetID: UUID?
    private var commitContinuation: CheckedContinuation<Void, Never>?

    init(preferences: PreferencesStore? = nil) {
        let resolvedPreferences = preferences ?? PreferencesStore()
        self.preferences = resolvedPreferences
        self.bridge = WebBridge()
        theme = resolvedPreferences.theme
        readingFont = resolvedPreferences.readingFont
        language = resolvedPreferences.language
        wireBridge()
    }

    // MARK: - Derived

    var activeDocument: MarkdownDocument? {
        guard let id = activeDocumentID else { return nil }
        return openDocuments.first { $0.id == id }
    }

    private var activeIndex: Int? {
        guard let id = activeDocumentID else { return nil }
        return openDocuments.firstIndex { $0.id == id }
    }

    var hasOpenDocuments: Bool { !openDocuments.isEmpty }

    // MARK: - Bridge wiring

    private func wireBridge() {
        bridge.onEditMarkdown = { [weak self] markdown in
            guard let self else { return }
            self.applyWysiwygCommit(markdown)
            self.commitContinuation?.resume()
            self.commitContinuation = nil
        }
        bridge.onUpdateOutline = { [weak self] entries in
            self?.outline = entries
        }
        bridge.onUpdateStats = { [weak self] stats in
            self?.stats = stats
        }
        bridge.onChangeActiveHeading = { [weak self] id in
            self?.activeHeadingID = id
        }
        bridge.onFindResult = { [weak self] result in
            self?.findResult = result
        }
        bridge.onFinishRender = {}
        bridge.onRequestSave = { [weak self] in
            Task { await self?.save() }
        }
    }

    /// Called once the WKWebView finishes loading `index.html`, so the first
    /// document renders even though the WebView loaded after `openDocuments`.
    func previewDidLoad() {
        bridge.setTheme(theme)
        bridge.setReadingFont(readingFont)
        bridge.setLanguage(LocalizationService.resolvedBCP47(for: language))
        bridge.setLayout(mode)
        pushActiveContentToPreview()
        // A short floor under the splash so fast loads don't just flash.
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            isPreviewReady = true
        }
    }

    private func pushActiveContentToPreview() {
        renderDebounceTask?.cancel()
        bridge.setContent(activeDocument?.content ?? "")
        bridge.setMode(editing: mode == .reading && isReadingEditing)
    }

    private func didChangeMode() {
        commitWysiwygIfNeeded()
        isReadingEditing = false
        bridge.setLayout(mode)
        bridge.setMode(editing: false)
    }

    func toggleReadEdit() {
        guard mode == .reading else { return }
        if isReadingEditing {
            commitWysiwygIfNeeded()
        } else {
            wysiwygTargetID = activeDocumentID
        }
        isReadingEditing.toggle()
        bridge.setMode(editing: isReadingEditing)
    }

    private func commitWysiwygIfNeeded() {
        guard mode == .reading, isReadingEditing else { return }
        bridge.requestCommit()
    }

    /// Fires a commit and waits for `didEditMarkdown` to land (with a ceiling,
    /// in case the WebView is gone), so callers like `save()` read content
    /// that includes the user's latest WYSIWYG edits.
    private func commitWysiwygAndWait() async {
        guard mode == .reading, isReadingEditing else { return }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            commitContinuation = continuation
            bridge.requestCommit()
            Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(800))
                self?.commitContinuation?.resume()
                self?.commitContinuation = nil
            }
        }
    }

    private func applyWysiwygCommit(_ markdown: String) {
        guard let targetID = wysiwygTargetID ?? activeDocumentID,
              let index = openDocuments.firstIndex(where: { $0.id == targetID }) else { return }
        openDocuments[index].content = markdown
        if !isReadingEditing { wysiwygTargetID = nil }
    }

    // MARK: - Opening

    func openFolderPanel() async {
        guard let url = FileService.presentOpenFolderPanel() else { return }
        await open(folder: url, bookmark: try? FileService.makeBookmark(for: url))
    }

    func open(folder url: URL, bookmark: Data?) async {
        workspace?.stopAccessing()
        var newWorkspace = Workspace(rootURL: url, bookmarkData: bookmark)
        newWorkspace.startAccessing()
        newWorkspace.reloadTree()
        workspace = newWorkspace
        expandedDirectoryURLs = [url]
        sidebarTab = .files
    }

    func openFilePanel() async {
        guard let url = FileService.presentOpenFilePanel() else { return }
        await openDocument(at: url)
    }

    func openDocument(at url: URL) async {
        if let existingIndex = openDocuments.firstIndex(where: { $0.url == url }) {
            activeDocumentID = openDocuments[existingIndex].id
            pushActiveContentToPreview()
            return
        }
        do {
            let content = try await FileService.readFile(at: url)
            var document = MarkdownDocument(url: url, name: url.lastPathComponent, content: content)
            document.markSaved()
            openDocuments.append(document)
            activeDocumentID = document.id
            pushActiveContentToPreview()
        } catch let error as RasterError {
            lastError = error
        } catch {
            lastError = .fileReadFailed(url)
        }
    }

    /// Loads a bundled sample as a fresh, unsaved document (never edits the
    /// bundle resource in place — `url` stays `nil` until the user saves).
    func openSampleDocument(name: String, content: String) {
        var document = MarkdownDocument(name: name, content: content)
        document.markSaved()
        openDocuments.append(document)
        activeDocumentID = document.id
        pushActiveContentToPreview()
    }

    func newFile() {
        let document = MarkdownDocument(name: String(localized: "Untitled.md"))
        openDocuments.append(document)
        activeDocumentID = document.id
        pushActiveContentToPreview()
    }

    func setActiveDocument(_ id: UUID) {
        guard id != activeDocumentID else { return }
        commitWysiwygIfNeeded()
        activeDocumentID = id
        isReadingEditing = false
        pushActiveContentToPreview()
    }

    // MARK: - Editing

    func updateActiveContent(_ newContent: String) {
        guard let index = activeIndex else { return }
        openDocuments[index].content = newContent
        // ~180ms debounce (CLAUDE.md): don't re-render the preview on every keystroke.
        renderDebounceTask?.cancel()
        renderDebounceTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled else { return }
            self?.bridge.setContent(newContent)
        }
    }

    func updateCursorPosition(line: Int, column: Int) {
        ln = line
        col = column
    }

    func updateSelection(_ range: NSRange) {
        selection = range
    }

    func applyFormat(_ command: FormatCommand) {
        guard let index = activeIndex else { return }
        let edit = TextFormatter.apply(command, to: openDocuments[index].content, selection: selection)
        openDocuments[index].content = edit.text
        renderDebounceTask?.cancel()
        bridge.setContent(edit.text)
        selection = edit.selection
        pendingSelection = edit.selection
    }

    // MARK: - Saving & closing

    /// Saves a document (the active one by default). Returns whether the file
    /// actually landed on disk — false covers both errors and a cancelled
    /// save panel, so callers like `saveAndClose()` never discard edits.
    @discardableResult
    func save(documentID: UUID? = nil) async -> Bool {
        guard let id = documentID ?? activeDocumentID else { return false }
        if id == activeDocumentID { await commitWysiwygAndWait() }
        guard var document = openDocuments.first(where: { $0.id == id }) else { return false }
        do {
            let targetURL: URL
            if let url = document.url {
                targetURL = url
            } else {
                guard let url = FileService.presentSavePanel(suggestedName: document.name) else { return false }
                targetURL = url
                document.url = url
                document.name = url.lastPathComponent
            }
            try await FileService.write(document.content, to: targetURL)
            document.markSaved()
            if let index = openDocuments.firstIndex(where: { $0.id == id }) {
                openDocuments[index] = document
            }
            showToast(String(format: String(localized: "Saved %@"), document.name))
            return true
        } catch let error as RasterError {
            lastError = error
            return false
        } catch {
            lastError = .fileWriteFailed(document.url ?? URL(fileURLWithPath: document.name))
            return false
        }
    }

    func requestClose(_ id: UUID) {
        guard let document = openDocuments.first(where: { $0.id == id }) else { return }
        if document.isDirty {
            pendingCloseDocumentID = id
        } else {
            closeTab(id)
        }
    }

    func cancelClose() {
        pendingCloseDocumentID = nil
    }

    func discardAndClose() {
        guard let id = pendingCloseDocumentID else { return }
        pendingCloseDocumentID = nil
        closeTab(id)
    }

    func saveAndClose() async {
        guard let id = pendingCloseDocumentID else { return }
        pendingCloseDocumentID = nil
        if await save(documentID: id) {
            closeTab(id)
        }
    }

    private func closeTab(_ id: UUID) {
        openDocuments.removeAll { $0.id == id }
        if activeDocumentID == id {
            activeDocumentID = openDocuments.last?.id
            pushActiveContentToPreview()
        }
    }

    // MARK: - Find

    func openFind() {
        // Find highlights live in the preview DOM — meaningless in editor-only mode.
        guard mode != .editor else { return }
        isFindOpen = true
    }

    func closeFind() {
        isFindOpen = false
        findQuery = ""
        bridge.find(query: "", direction: "reset")
    }

    func setFindQuery(_ query: String) {
        findQuery = query
        bridge.find(query: query, direction: "current")
    }

    func findStep(_ direction: Int) {
        bridge.find(query: findQuery, direction: direction >= 0 ? "next" : "prev")
    }

    // MARK: - Outline

    func scrollToHeading(_ id: String) {
        bridge.scrollToHeading(id)
    }

    // MARK: - Export

    func exportActivePDF() async {
        guard let document = activeDocument else { return }
        commitWysiwygIfNeeded()
        guard let url = FileService.presentExportPanel(
            suggestedName: baseName(document.name) + ".pdf",
            contentType: .pdf
        ) else { return }
        do {
            try await ExportService.exportPDF(
                markdown: document.content,
                language: LocalizationService.resolvedBCP47(for: language),
                to: url
            )
            showToast(String(format: String(localized: "PDF exported — %@"), url.lastPathComponent))
        } catch let error as RasterError {
            lastError = error
        } catch {
            lastError = .exportFailed(error.localizedDescription)
        }
    }

    func exportActiveHTML() async {
        guard let document = activeDocument else { return }
        commitWysiwygIfNeeded()
        let htmlType = UTType.html
        guard let url = FileService.presentExportPanel(
            suggestedName: baseName(document.name) + ".html",
            contentType: htmlType
        ) else { return }
        do {
            try await ExportService.exportHTML(
                markdown: document.content,
                title: baseName(document.name),
                language: LocalizationService.resolvedBCP47(for: language),
                to: url
            )
            showToast(String(format: String(localized: "HTML exported — %@"), url.lastPathComponent))
        } catch let error as RasterError {
            lastError = error
        } catch {
            lastError = .exportFailed(error.localizedDescription)
        }
    }

    func printActiveDocument() async {
        guard let document = activeDocument else { return }
        commitWysiwygIfNeeded()
        do {
            try await ExportService.printDocument(
                markdown: document.content,
                language: LocalizationService.resolvedBCP47(for: language)
            )
        } catch let error as RasterError {
            lastError = error
        } catch {
            lastError = .exportFailed(error.localizedDescription)
        }
    }

    func openZipSheet(scope urls: [URL]) {
        zipScopeURLs = urls
        isZipSheetPresented = true
    }

    func confirmZipExport() async {
        guard let workspace, !zipScopeURLs.isEmpty else {
            isZipSheetPresented = false
            return
        }
        isZipSheetPresented = false
        let items = zipScopeURLs.flatMap { collectMarkdownFiles(under: $0, root: workspace.rootURL) }
        guard let destination = FileService.presentExportPanel(suggestedName: workspace.name + ".zip", contentType: .zip) else { return }
        do {
            let summary = try await ExportService.exportZIP(
                items: items,
                options: zipOptions,
                language: LocalizationService.resolvedBCP47(for: language),
                to: destination
            )
            showToast(String(format: String(localized: "ZIP exported — %lld files"), summary.exportedCount))
        } catch let error as RasterError {
            lastError = error
        } catch {
            lastError = .exportFailed(error.localizedDescription)
        }
    }

    private func collectMarkdownFiles(under url: URL, root: URL) -> [ZipExportItem] {
        var isDirectory: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        let relative: (URL) -> String = { candidate in
            let rootPath = root.standardizedFileURL.path
            let candidatePath = candidate.standardizedFileURL.path
            guard candidatePath.hasPrefix(rootPath) else { return candidate.lastPathComponent }
            return String(candidatePath.dropFirst(rootPath.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }
        if !isDirectory.boolValue {
            return [ZipExportItem(relativePath: relative(url), sourceURL: url)]
        }
        let node = FileNode.buildTree(at: url)
        var items: [ZipExportItem] = []
        func walk(_ node: FileNode) {
            if node.isDirectory {
                (node.children ?? []).forEach(walk)
            } else {
                items.append(ZipExportItem(relativePath: relative(node.url), sourceURL: node.url))
            }
        }
        walk(node)
        return items
    }

    // MARK: - Toast

    func showToast(_ message: String) {
        toastTask?.cancel()
        toastMessage = message
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.4))
            guard !Task.isCancelled else { return }
            self?.toastMessage = nil
        }
    }

    // MARK: - Helpers

    func baseName(_ name: String) -> String {
        (name as NSString).deletingPathExtension
    }
}
