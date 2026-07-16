# CLAUDE.md — Raster

Project context for Claude Code. Read before generating or changing code.

---

## What this is

**Raster** is a native **macOS** Markdown reader and editor. It renders `.md` files with reading-grade quality (clean typography, good contrast) and also edits them: a source pane with live preview, plus an editable reading mode (WYSIWYG). It ships a folder explorer and VS Code-style tabs.

Branding note: the reference behind the name lives **only in the name and the logo mark**. Nothing else in the product carries it — no themed visuals, no easter eggs. The reading surface is always clean. Non-negotiable rule: aesthetics never compromise legibility or function.

---

## Stack decision

**Primary — what these docs assume:**
- **SwiftUI** (macOS 14 Sonoma+), **Swift 5.9+**, with **AppKit** where needed (window, menus, `NSOpenPanel`).
- **Rendering/editing core in a `WKWebView`**: the rendered preview (and the reading-mode WYSIWYG) runs in a WebView that embeds the already-validated JS engine (marked, highlight.js, mermaid, turndown). JS/CSS/HTML assets are **bundled in the app** and loaded via `file://` — **no CDN, no network** (offline-first).
- **Source editor**: a wrapped `NSTextView` (via `NSViewRepresentable`) with lightweight Markdown highlighting. Do not use plain `TextEditor` (insufficient control).

**Alternative (not assumed here):** Tauri (Rust + web front end) reuses 100% of the web prototype and ships faster, with native FS and menus. If the project moves to Tauri, **ask to regenerate this file** — the architecture changes.

Why a WebView for the preview: Mermaid, syntax highlighting, and the WYSIWYG (contenteditable + turndown) are already solved in JS. Rewriting them natively would be expensive and fragile. The WebView isolates that part; the native layer owns everything else (files, windows, shortcuts, export).

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│  Native layer (SwiftUI / AppKit)                          │
│  • Window, menus, shortcuts, sidebar, tabs                │
│  • File system (open folder, read/save)                   │
│  • App state (open documents, mode, theme, language)      │
│  • Export (PDF via print, HTML)                            │
└───────────────┬───────────────────────┬───────────────────┘
                │  source = Markdown      │  bridge (messages)
                ▼                         ▼
┌───────────────────────┐   ┌───────────────────────────────┐
│ Source editor          │   │ Web core (WKWebView)           │
│ NSTextView + highlight  │   │ marked + highlight + mermaid   │
│ (Editor/Split modes)    │   │ + turndown (reading WYSIWYG)   │
└───────────────────────┘   └───────────────────────────────┘
```

**Single source of truth = the active document's Markdown string** (`MarkdownDocument.content`). Both the `NSTextView` and the WebView derive from it.

Flow:
1. Opening/switching a file → load Markdown from disk → `content`.
2. Editor/Split mode: user edits in the `NSTextView` → updates `content` → sent to the WebView for re-render (~180 ms debounce).
3. Reading + Edit (WYSIWYG): user edits the rendered content in the WebView → on blur / tab switch / save, the WebView converts back to Markdown (turndown) and returns it to the native layer (`didEditMarkdown`) → updates `content` and the `NSTextView`.

---

## Repository layout

```
Raster/
├── Raster.xcodeproj
├── Raster/
│   ├── App/
│   │   ├── RasterApp.swift          # @main, WindowGroup, menu commands
│   │   └── AppState.swift           # central ObservableObject
│   ├── Models/
│   │   ├── MarkdownDocument.swift    # id, url, name, content, isDirty, bookmark
│   │   ├── Workspace.swift           # root folder + tree + security-scoped access
│   │   ├── FileNode.swift            # tree node (dir/file)
│   │   └── EditorMode.swift          # enum: editor / split / reading (+ isEditing)
│   ├── Views/
│   │   ├── MainWindowView.swift      # layout: sidebar | (tabs + panes) | status
│   │   ├── Sidebar/
│   │   │   ├── ExplorerView.swift     # segmented Files/Outline
│   │   │   ├── FileTreeView.swift     # folder tree
│   │   │   └── OutlineView.swift      # table of contents (scroll-spy)
│   │   ├── TabBarView.swift          # VS Code-style tabs (dirty dot, close)
│   │   ├── Editor/
│   │   │   ├── SourceEditor.swift     # NSViewRepresentable wrapping NSTextView
│   │   │   └── MarkdownHighlighter.swift
│   │   ├── Preview/
│   │   │   ├── PreviewWebView.swift   # WKWebView + bridge
│   │   │   └── WebBridge.swift        # WKScriptMessageHandler
│   │   ├── Toolbar/
│   │   │   ├── ModeSwitch.swift
│   │   │   ├── FormatToolbar.swift
│   │   │   └── FindBar.swift
│   │   └── StatusBarView.swift
│   ├── Services/
│   │   ├── FileService.swift         # open folder, read/save, bookmarks
│   │   ├── ExportService.swift       # HTML, paginated PDF, ZIP bundles, print
│   │   ├── LocalizationService.swift # language override mechanics
│   │   └── PreferencesStore.swift    # theme, reading font, language (UserDefaults)
│   └── WebCore/                       # bundled resource (folder reference)
│       ├── index.html
│       ├── engine.js                 # render, enhance, outline, WYSIWYG, find
│       ├── strings.js                # preview UI label dictionary (en / pt-BR)
│       ├── styles.css                # tokens shared with the app
│       ├── sample.en.md              # sample document (English)
│       ├── sample.pt-BR.md           # sample document (Brazilian Portuguese)
│       └── vendor/                    # marked, highlight, mermaid, turndown (local)
├── RasterTests/
└── RasterUITests/
```

`WebCore/` must be added as a **folder reference** (blue folder) to preserve structure in the bundle. Load with `loadFileURL(indexURL, allowingReadAccessTo: webCoreDir)`.

---

## Domain model

```swift
struct MarkdownDocument: Identifiable {
    let id: UUID
    var url: URL?          // nil = new unsaved file
    var name: String
    var content: String    // SOURCE OF TRUTH (Markdown)
    var isDirty: Bool
    var bookmarkData: Data? // security-scoped, for reopening/saving
}

enum EditorMode { case editor, split, reading }
// In .reading, AppState.isReadingEditing toggles Read vs Edit.

final class AppState: ObservableObject {
    @Published var openDocuments: [MarkdownDocument]
    @Published var activeDocumentID: UUID?
    @Published var workspace: Workspace?
    @Published var mode: EditorMode = .split
    @Published var isReadingEditing = false
    @Published var theme: Theme = .dark              // .dark | .light
    @Published var readingFont: ReadingFont = .serif // .serif | .sans
    @Published var explorerVisible = true
    @Published var sidebarTab: SidebarTab = .files   // .files | .outline
    @Published var language: AppLanguage = .system   // .system | .en | .ptBR
}
```

---

## JS ↔ Swift bridge contract

All JS→Swift messages via `window.webkit.messageHandlers.raster.postMessage({type, payload})`. Swift→JS via `evaluateJavaScript("window.raster.<fn>(...)")`.

**Swift → JS (commands):**
- `setContent(markdown: String)` — re-renders the preview.
- `setTheme("dark"|"light")` — switches theme (re-initializes Mermaid).
- `setMode("read"|"edit")` — toggles the WYSIWYG (contenteditable).
- `setReadingFont("serif"|"sans")`.
- `setLanguage("en"|"pt-BR")` — switches the preview's UI labels (callouts, copy button, editing banner); never touches content.
- `requestCommit()` — asks the WYSIWYG for its current Markdown (triggers `didEditMarkdown`).
- `find(query: String, direction: "next"|"prev"|"reset")`.
- `scrollToHeading(id: String)`.

**JS → Swift (events):**
- `didEditMarkdown(markdown)` — after a WYSIWYG commit.
- `didUpdateOutline([{ level, title, id }])` — for the Outline panel + scroll-spy.
- `didUpdateStats({ words, readingMinutes })` — status bar (formatting is done in Swift).
- `didChangeActiveHeading(id)` — outline highlight.
- `findResult({ current, total })`.
- `didFinishRender` — fired when the document (including all Mermaid SVGs) is fully rendered; export waits for this.
- `requestSave` — user triggered save from inside the WebView.

**WYSIWYG rules (implemented in `engine.js`, validated in the prototype):**
- **Code** and **Mermaid** blocks become `contenteditable="false"` in edit mode and are reconstructed by turndown rules from `data-src`/`data-lang` — they never corrupt on round-trip.
- Callouts (`> [!NOTE]` etc.) convert back to blockquotes with the `[!TYPE]` marker.
- Commit (turndown → Markdown) happens only if the user actually edited in the WYSIWYG; pure reading never touches the source.

---

## Commands

```bash
# Open in Xcode
open Raster.xcodeproj

# Build (CLI)
xcodebuild -scheme Raster -configuration Debug build

# Tests
xcodebuild test -scheme Raster -destination 'platform=macOS'

# Lint / formatting (add via SPM plugin or brew)
swiftlint
swift-format lint --recursive Raster/
```

Day-to-day: Xcode → ⌘R. There is no build step for `WebCore/` (static bundled assets).

---

## v1 scope (must-have)

1. Open a **folder** (navigable tree) and standalone **files**.
2. **VS Code-style tabs**: dirty dot, close, switch, horizontal scroll.
3. Three modes: **Editor**, **Split**, **Reading**. Reading has a **Read / Edit** toggle (WYSIWYG).
4. GFM Markdown rendering: headings, tables, task lists, strikethrough, links.
5. Native **Mermaid** diagrams; **syntax highlighting** with a copy button.
6. **Callouts** `[!NOTE] [!TIP] [!WARNING] [!IMPORTANT] [!CAUTION]`.
7. **Outline** with scroll-spy.
8. In-document **find** (⌘F) with highlight and navigation.
9. Real **save** to disk (⌘S). **Export HTML**, **first-class Export PDF** (⇧⌘E, paginated, no print panel), and **Export as ZIP** for a set of `.md` files (multi-select in the tree or the whole folder; optional folder structure and rendered-HTML inclusion).
10. Light/dark **theme**; serif/sans **reading font**.
11. Status bar: word count, reading time, line/column.
12. Native menus (File, Edit, View, Format) + standard macOS shortcuts.
13. **Localization: English + Brazilian Portuguese** (full UI; user content is never translated). Default: system language, with an override in Preferences.

---

## Out of scope (v1)

- Cloud sync, real-time collaboration.
- Plugin system.
- Editor↔preview scroll sync (nice-to-have, phase 2).
- App Store / strict sandboxing (v1 may be non-sandboxed or use `NSOpenPanel` + security-scoped bookmarks). Harden only if distributing.
- iOS/iPadOS.

---

## Principles

- **Legibility first.** If an aesthetic choice hurts reading or function, it goes.
- **Branding lives in the name and the logo only.** Never on the reading surface.
- **Native macOS conventions.** Shortcuts, menus, window and file behavior as a Mac app should.
- **Offline-first.** No runtime network dependency.
- **Single source of truth** (the Markdown string). Everything else derives from it.

---

## Internationalization (en + pt-BR)

Two languages in v1: **English** — development language and fallback for any other locale — and **Brazilian Portuguese**. Every user-visible string localizes; **user content never does**.

**Native layer (SwiftUI):**
- Use a **String Catalog** (`Localizable.xcstrings`) with `en` as the development language and `pt-BR` as the second locale. No legacy `.strings`.
- Never hardcode UI text in views: always `String(localized:)` / `LocalizedStringKey`. Pluralization via the catalog (e.g. "%lld words").
- Menus, dialogs, tooltips, Preferences, confirmation alerts: all through the catalog.
- Manual override: an `AppLanguage` preference (`system | en | ptBR`) in `PreferencesStore`. `system` defers to macOS (which already supports per-app language in System Settings). The override applies via `AppleLanguages`/relaunch or bundle injection — decide at implementation time, but wrap it in `LocalizationService` so the UI never knows the mechanism.

**Web core (`WebCore/`):**
- `engine.js` must not hardcode labels. `strings.js` holds a per-language dictionary covering: callout labels (Note/Nota, Tip/Dica, Warning/Atenção, Important/Importante, Caution/Cuidado), copy/copied button, the WYSIWYG banner ("editing — code and diagrams locked"), Mermaid error text, empty states ("No headings." / "Sem títulos."), find placeholder.
- Language is **pushed by Swift**, never detected in the WebView: bridge command `setLanguage("en"|"pt-BR")`, called on load and when the preference changes. JS re-renders labels without touching content.
- **Callout syntax stays English in the file** (`[!NOTE]` — GFM standard); only the rendered label localizes.
- Sample document ships in both languages (`sample.en.md`, `sample.pt-BR.md`); the native layer picks which to load.
- Stats: JS sends raw numbers (`didUpdateStats`); localized formatting ("842 words · 4 min") happens in Swift via the catalog.

**General rules:**
- Code identifiers in English; UI strings via the catalog (never inline).
- Keyboard shortcuts identical across languages.
- The brand (`raster`) and established terms (Markdown, Mermaid) do not translate.
- Size layout for pt-BR (roughly 20–30% longer); no fixed widths that truncate "Dividido".
- Acceptance test: run the app under `en` and `pt-BR` locales and sweep every screen — zero strings in the wrong language, zero truncation.

---

## Export (PDF & ZIP)

**PDF (first-class, ⇧⌘E):**
- Goal: one save dialog → one **paginated** PDF of the rendered document, using the reading typography on a light background (export always uses the light/print stylesheet regardless of app theme), no UI chrome.
- **Do not use `WKWebView.createPDF(configuration:)` for this** — it produces a single long page. For paginated output, drive `webView.printOperation(with: NSPrintInfo)` targeting a PDF destination (`NSPrintInfo.jobDisposition = .save`, `NSPrintJobSavingURL`), run it without showing panels. Wrap this in `ExportService.exportPDF(document:to:)`.
- Render in a dedicated off-screen WebView loaded with the print stylesheet (don't repurpose the visible preview mid-edit; commit WYSIWYG first via `requestCommit()`).
- Mermaid SVGs must be fully rendered before printing — wait for the engine's "render complete" signal (add a `didFinishRender` bridge event if not present).
- File → Print… (⌘P) remains as a normal print path with the native panel.

**ZIP (set of `.md` files):**
- Entry points: explorer context menu on a multi-selection ("Export as ZIP…"), or File menu ("Export Folder as ZIP…" exporting the workspace root when nothing is selected).
- Options sheet before the save dialog: **preserveStructure** (default true — keeps relative paths from the workspace root; false flattens, deduplicating name collisions with a numeric suffix) and **includeRenderedHTML** (default false — when true, writes a sibling `.html` per `.md`, rendered through the same engine/print stylesheet).
- Include only `.md`/`.markdown`/`.txt`. Skip hidden files. If any selected document has unsaved changes, prompt to save before exporting (export always reads from disk, never from memory).
- **Implementation:** macOS has no public zip-writing API. Add **ZIPFoundation** via SPM (`Archive(url:accessMode:.create)`, `addEntry(with:relativeTo:)`) — small, maintained, no shell-out. Do **not** shell out to `/usr/bin/zip` (fragile under sandbox) and do not use AppleArchive (`.aar`, not `.zip`).
- Stream file-by-file on a background task; report progress for large sets; collect per-file errors and finish the archive, then show a summary ("Exported 14 files, 1 skipped: …") instead of aborting on the first failure.
- Each source file read must respect security-scoped access (see Constraints); the workspace bookmark covers children of the opened folder.

---

## Constraints & gotchas

- **Bundle JS libraries locally** (`WebCore/vendor/`). Never reference a CDN.
- **Dependencies**: keep them minimal. The only sanctioned SPM package in v1 is **ZIPFoundation** (ZIP export). Anything else needs a written justification here.
- **PDF export ≠ `WKWebView.createPDF`** (single-page). Use the print-operation path described in the Export section.
- **`WKWebView` + `file://`**: use `loadFileURL(_:allowingReadAccessTo:)` with the `WebCore` directory.
- **The WYSIWYG round-trip is potentially lossy** for exotic structures — that's why code/Mermaid are locked and reconstructed from `data-src`. Keep that contract when evolving the parser.
- **Never re-render the WebView while the user types in the WYSIWYG** (loses the caret). Re-render from source only outside edit mode, or after a commit.
- **File access**: store `bookmarkData` (security-scoped) to reopen the folder/file across sessions and to save. Always pair `startAccessingSecurityScopedResource()` / `stop...`.
- **Safe saving**: atomic writes (`Data.write(to:options:.atomic)`).
- **Mermaid's theme** must be re-initialized when the app theme changes.

---

## Code conventions

- Swift API Design Guidelines. Descriptive names, no obscure abbreviations.
- **No force-unwraps** (`!`) outside tests; use `guard let` / `if let` and typed errors (`enum RasterError: Error`).
- Small, composed SwiftUI views; logic lives in `AppState`/Services, not in views.
- Async/await for file I/O; never block the main thread.
- Comments explain **why**, not the obvious. UI strings always via the String Catalog — never inline.
- One type per file (except small helper types).

---

## Tests & Definition of Done

- **Unit**: document model (dirty, save/load), `FileService`, outline parsing, WYSIWYG round-trip on samples (Markdown → HTML → Markdown stable for prose/tables/lists), ZIP building (structure preserved/flattened, name-collision suffixes, skip rules).
- **UI**: open folder, switch tabs, switch modes, edit in reading mode and save, export PDF (file exists, multi-page for a long doc), export ZIP from a multi-selection.
- **DoD for a feature**: compiles without warnings; covered by tests where there's logic; has its menu item and shortcut; works in both themes and both languages; no reading regression in the preview.
