<p align="center">
  <img src="Docs/brand/logo-transparent.png" alt="raster.md" width="420">
</p>

<p align="center"><strong>Markdown Editor for macOS</strong><br>Fast. Simple. Open Source.</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-blue" alt="macOS 14+">
  <img src="https://img.shields.io/badge/Swift-6-orange" alt="Swift 6">
  <img src="https://img.shields.io/badge/UI-SwiftUI%20%2B%20AppKit-purple" alt="SwiftUI + AppKit">
  <img src="https://img.shields.io/badge/languages-EN%20%7C%20PT--BR-ff4ecd" alt="English and Brazilian Portuguese">
</p>

---

**Raster** is a native macOS Markdown reader and editor built around one idea: *reading well comes first*. It renders `.md` files with reading-grade typography, and it also edits them — a source pane with live preview, plus an editable reading mode (WYSIWYG). Markdown has become the universal output format of AI; Raster is a fast, beautiful place to read, review, and edit those files.

## Features

- **Three modes** — **Editor** (source only), **Split** (source + live preview), and **Reading** (rendered text at a comfortable measure), switchable with ⌘1/⌘2/⌘3.
- **Editable reading mode** — press *Edit* inside Reading mode (⌘E) and fix typos directly in the rendered text. Code blocks and diagrams stay locked so the round-trip back to Markdown never corrupts them.
- **Full GFM rendering** — headings, tables, task lists (clickable checkboxes that write back to the source), strikethrough, links, images.
- **Mermaid diagrams** as first-class blocks, with theme-aware re-rendering.
- **Syntax highlighting** with a hover *copy* button on every code block.
- **Callouts** — `[!NOTE]`, `[!TIP]`, `[!WARNING]`, `[!IMPORTANT]`, `[!CAUTION]`, with localized labels.
- **Folder explorer** with VS Code-style tabs (dirty dot, close, ⌘-click multi-select, context menu).
- **Outline panel** with scroll-spy that tracks your position as you read.
- **Find in document** (⌘F) with match highlighting and navigation.
- **Real files** — open folders and standalone files, save atomically with ⌘S, security-scoped bookmarks.
- **Export** — standalone HTML, first-class paginated PDF (⇧⌘E, no print panel), and ZIP bundles of multiple files (optionally with rendered HTML alongside each source file).
- **Light & dark themes**, serif & sans reading fonts.
- **Fully bilingual** — English and Brazilian Portuguese, following the system language with an in-app override.
- **Offline-first** — every dependency is bundled; the app never touches the network.

## Building

Requirements: **Xcode 16+** on **macOS 14 Sonoma** or newer.

```bash
git clone https://github.com/tboschese/Raster.git
cd Raster
open Raster.xcodeproj   # then ⌘R
```

Or from the command line:

```bash
xcodebuild -scheme Raster -configuration Debug build
xcodebuild -scheme Raster -destination 'platform=macOS' test   # unit tests
```

The only package dependency is [ZIPFoundation](https://github.com/weichsel/ZIPFoundation) (ZIP export), resolved automatically by Xcode.

## Architecture

The native layer owns everything a Mac app should own; a web core owns rendering.

```
┌─────────────────────────────────────────────────────────┐
│  Native layer (SwiftUI / AppKit)                          │
│  window · menus · shortcuts · explorer · tabs · file I/O  │
│  app state · export (PDF / HTML / ZIP)                    │
└───────────────┬───────────────────────┬───────────────────┘
                │  source = Markdown      │  JS ⇄ Swift bridge
                ▼                         ▼
┌───────────────────────┐   ┌───────────────────────────────┐
│ Source editor          │   │ Web core (WKWebView)           │
│ NSTextView + light      │   │ marked · highlight.js ·        │
│ Markdown highlighting   │   │ mermaid · turndown (WYSIWYG)   │
└───────────────────────┘   └───────────────────────────────┘
```

- **Single source of truth**: the active document's Markdown string. Both panes derive from it — the editor re-renders the preview through a ~180 ms debounce, and WYSIWYG edits convert back through turndown on commit.
- **The bridge** is a small typed message contract (`setContent`, `setTheme`, `find`, `didEditMarkdown`, `didUpdateOutline`, `didFinishRender`, …) — see `Raster/Views/Preview/WebBridge.swift` and `Raster/WebCore/engine.js`.
- **Exports render through the same engine** as the live preview (an off-screen WKWebView on a light/print stylesheet), so what you export is exactly what you read. PDF uses the AppKit print-operation path for true pagination.
- All JS libraries are vendored in `Raster/WebCore/vendor/` — no CDN, no runtime network.

## Project layout

```
Raster/
├── Raster.xcodeproj
├── Raster/
│   ├── App/            # entry point, menu commands, central AppState
│   ├── Models/         # MarkdownDocument, Workspace, FileNode, …
│   ├── Services/       # file I/O, export, preferences, localization
│   ├── Views/          # SwiftUI: window, sidebar, tabs, editor, preview
│   ├── Resources/      # String Catalog (en / pt-BR), asset catalog
│   └── WebCore/        # bundled rendering engine (HTML/CSS/JS + vendor)
├── RasterTests/        # unit tests (model, formatter, ZIP, engine)
└── RasterUITests/      # UI smoke tests
```

## Testing

Unit tests cover the document model, file I/O, the Markdown text formatter, folder-tree building, ZIP structure/name-collision rules, and the rendering engine end-to-end (a real WKWebView asserting outline extraction and stats through the bridge).

```bash
xcodebuild -scheme Raster -destination 'platform=macOS' test -only-testing:RasterTests
```

## Roadmap

See [ROADMAP.md](ROADMAP.md) for what's planned next.

## Brand

Logo, palette, and usage guidelines live in [Docs/brand/](Docs/brand/). The reference behind the name lives only in the name and the logo — the reading surface stays clean.

## License

MIT — see [LICENSE](LICENSE).
