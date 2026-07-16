# Raster — Roadmap

What shipped in v1.0, what's next in v1.1, and where the product is headed.
Ordering within each release reflects priority. Principles stay fixed:
legibility first, native macOS conventions, offline-first, single source of
truth (the Markdown string).

## v1.0 (current)

Folder explorer · tabs · Editor/Split/Reading modes · editable reading mode
(WYSIWYG with locked code/diagrams) · GFM + Mermaid + callouts + highlighting ·
outline with scroll-spy · find in document · atomic save · HTML/PDF/ZIP export ·
light/dark themes · serif/sans reading fonts · English + Brazilian Portuguese.

## v1.1 — polish the daily loop

The theme: everything between opening the app and saving a file should feel
effortless.

**Session restore.** Reopen the last workspace and tabs on launch (the
security-scoped bookmarks are already stored — persist and resolve them).
Includes per-document scroll position.

**Editor quality of life.**
- Preserve the undo stack across formatting actions (today a toolbar action
  resets NSTextView's undo history).
- Incremental Markdown highlighting (only re-highlight the edited paragraph;
  large documents currently re-scan on every keystroke).
- Find in the source editor (NSTextView's find bar) so ⌘F works in Editor
  mode too, not just over the preview.
- Auto-continue lists and task lists on Return; Tab/⇧Tab indent list items.

**Explorer completeness.**
- Shift-click range selection (⌘-click toggling shipped in v1.0).
- New file / rename / delete from the context menu, with FSEvents watching so
  external changes appear live.
- Drag tabs to reorder; middle-click closes a tab.

**Export hardening.**
- Prompt to save dirty documents before ZIP export (spec'd in CLAUDE.md,
  deferred in v1.0).
- Progress reporting + cancel for large ZIP exports; summary sheet listing
  skipped files.
- "Copy as rich text" for pasting rendered Markdown into Mail/Notes.

**Reading experience.**
- Editor ↔ preview scroll sync in Split mode (phase 2 in the spec).
- Adjustable reading measure and font size (⌘+/⌘−).
- Focus mode: hide chrome, center the column, dim everything but the text.

## v1.2 — the knowledge-base release

**Whole-folder search** — ripgrep-style content search across the workspace
from the sidebar, with match previews.

**Wiki links** — `[[file]]` links between documents in the workspace,
clickable in the preview, with a backlinks panel.

**Local history** — lightweight automatic snapshots on save (keep N per file),
with a compare/restore UI. Pairs with autosave-after-idle.

**Quick Look extension** — render `.md` beautifully in Finder's space-bar
preview using the same WebCore engine.

**Front matter** — recognize YAML front matter, render it as a neat metadata
card instead of raw text.

## Later / exploring

- Presentation mode (split on `---`, one slide per section).
- Print stylesheet options (margins, page numbers, headers).
- Mermaid diagram export as PNG/SVG from the context menu.
- App Store distribution (full sandboxing audit; v1 runs non-sandboxed).
- Additional UI languages beyond en/pt-BR once the catalog workflow is proven.
- iOS/iPadOS companion (explicitly out of scope until the Mac app is complete).

## Known gaps being tracked

- WYSIWYG round-trip is intentionally conservative: exotic structures
  (nested HTML, footnotes) may normalize on commit. Code/Mermaid are locked
  and always safe.
- The outline lists headings H1–H3 only, by design.
- UI test coverage is a smoke suite; deeper interaction tests planned
  alongside v1.1 explorer work.
