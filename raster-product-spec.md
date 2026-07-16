# Raster — Product Spec

Product specification for prototyping in Claude Design. A native **macOS** Markdown reader and editor.

---

## 1. Vision

A Markdown reader and editor with an absolute focus on **reading well** — and editing without friction, whether in the source or directly in the rendered text.

Markdown has become the universal output format of AI. Everyone generates `.md` all day, then reads it in a generic preview or a raw code editor. Raster is the fast, beautiful place to read, review, and edit those files, with the solidity of a real Mac app.

**One-liner:** *Read and edit Markdown the way a Mac app should — clean, fast, offline.*

Branding: the name **Raster** and a small logo mark are the whole identity. No themed visuals anywhere else in the product. The reading surface is always clean.

---

## 2. Problem & opportunity

- Markdown previews in most tools are ugly or heavy (giant Electron apps), and code editors aren't made for *reading*.
- Mermaid diagrams, callouts, and tables rarely render well in the same place you edit.
- Switching between "view it nicely" and "edit it" usually means two apps.
- Opportunity: a native, lightweight, readable app that unifies comfortable reading + editing (source **and** WYSIWYG) + folder navigation with tabs.

---

## 3. Audience & jobs-to-be-done

**Audience:** people who live in Markdown — PMs, tech leads, researchers, anyone writing documentation, specs, notes, and content. Comfortable with files and folders; they value legibility and speed.

**JTBD:**
- *When I receive an AI-generated `.md`, I want to read it clean and well-typeset, so I can review it quickly without noise.*
- *When I write a governance document, I want callouts and diagrams rendered while I edit, so I can see the final result.*
- *When I work in a folder of notes, I want to move between files in tabs, like in my code editor.*
- *When I just need to fix a paragraph, I want to edit directly in the rendered text, without dropping back to raw Markdown.*

---

## 4. Product principles

1. **Legibility first.** No aesthetic choice may make reading worse.
2. **Branding lives in the name and the logo only.** Nothing else in the UI carries a theme; the reading surface is always clean.
3. **Native to the Mac.** Menus, shortcuts, window and file behavior like a real Mac app. Offline.
4. **Editing never gets in the way of reading.** Reading mode is the default; editing is one tap away.

---

## 5. v1 scope

**In:** folder explorer, tabs, 3 modes (Editor/Split/Reading), editable reading mode (WYSIWYG), full GFM, Mermaid, syntax highlighting, callouts, outline with scroll-spy, find, real save to disk, HTML export, **first-class PDF export**, **ZIP export of a set of `.md` files**, light/dark theme, serif/sans reading font, status bar, **languages: English and Brazilian Portuguese**.

**Out (phase 2+):** editor↔preview scroll sync, cloud sync, collaboration, plugins, iOS.

---

## 6. Information architecture & layout

Single window, four regions:

```
┌──────────────────────────────────────────────────────────────┐
│ TOOLBAR  [☰] raster · [Editor|Split|Reading] · [B I S H …]    │
│                              find · Aa · theme · File ▾        │
├───────────┬──────────────────────────────────────────────────┤
│ EXPLORER  │ TABS:  read-me.md ×  |  spec.md •×  |  notes.md ×  │
│ [Files|   ├──────────────────────┬───────────────────────────┤
│  Outline] │                      │                            │
│  📁 docs   │   EDITOR (source)     │   PREVIEW (rendered)       │
│   📄 a.md  │   raw Markdown        │   or editable READING      │
│   📄 b.md  │                      │                            │
│  📁 specs  │                      │                            │
├───────────┴──────────────────────┴───────────────────────────┤
│ STATUS: ◆ RASTER · spec.md · 842 words · 4 min · ln 12 col 3  │
└──────────────────────────────────────────────────────────────┘
```

- **Toolbar** (top): explorer toggle, logo, mode switch, formatting tools, find, reading font, theme, File menu.
- **Explorer** (left, collapsible): segmented **Files / Outline**. Files = folder tree; Outline = table of contents for the active document with scroll-spy.
- **Tabs** (above the panes): open files, unsaved indicator (amber dot), close.
- **Panes**: source editor and/or preview, per mode.
- **Status bar** (bottom): file name, words, reading time, line/column.
- **Native menu bar** (macOS): File, Edit, View, Format, Window, Help.

In a narrow window, the explorer becomes an overlay.

---

## 7. Modes (detailed)

Segmented control in the toolbar: **Editor · Split · Reading**.

- **Editor** — source Markdown only, full width. For focused writing. Formatting tools insert syntax (`**`, `##`, lists…).
- **Split** — source on the left, rendered preview on the right. Edit in source, see it live (debounced). Default for reviewing.
- **Reading** — rendered view only, centered, comfortable measure (~74ch). A **Read / Edit** toggle appears:
  - **Read** (default): rendered, not editable. Clean reading.
  - **Edit** (WYSIWYG): the rendered text itself becomes editable. Formatting via shortcuts/toolbar. A thin amber banner at the top reads "editing — code and diagrams locked". Code blocks and Mermaid diagrams are locked in this mode (edit those in the source pane); everything else (prose, headings, lists, tables, callouts) is editable and converts back to Markdown on blur / tab switch / save.

Read↔Edit transition: subtle, no showy animation. The banner appears/disappears.

---

## 8. Screens & states

1. **Welcome / no folder** — explorer shows a dashed "Open Folder" button; the preview shows the sample `read-me.md` (which also demonstrates the features). An inviting state, not a dead-empty one.
2. **Folder open** — tree populated; the first file may open automatically.
3. **Editing (Split)** — caret in the source, preview updating.
4. **Reading** — preview in focus, outline highlighting the visible section.
5. **Editing in reading mode (WYSIWYG)** — amber banner, locked blocks discreetly marked.
6. **Find open** — floating bar in the preview corner, `3/12` counter, ↑↓ navigation, matches highlighted (current one in solid amber).
7. **Unsaved document** — amber dot on the tab and in the menu; ⌘S saves.
8. **Exporting** — Export PDF/HTML: native save dialog, then a brief confirmation. **Export as ZIP**: a small sheet (scope summary, "Preserve folder structure", "Include rendered HTML") → save dialog → confirmation toast. Errors (e.g. unreadable file) list the affected files without aborting the rest.
9. **Preferences** — native window: theme, reading font, editor font size, tab size, **language (System · English · Português (Brasil))**.
10. **Diagram error** — invalid Mermaid shows a mono/red message in place of the diagram without breaking the rest of the preview.
11. **No tabs open** — empty preview with an "Open a file" hint.

---

## 9. Core flows

**Open a folder and edit**
1. Toolbar → explorer toggle → "Open Folder" → pick in Finder.
2. Tree loads. Click a file → opens in a tab, becomes active.
3. Edit (Split). Amber dot appears. ⌘S saves to disk. Dot clears.

**Edit in reading mode**
1. **Reading** mode → **Edit** button.
2. Fix a paragraph directly in the rendered text.
3. Blur / switch tab / ⌘S → converts back to Markdown and saves.

**Switch files**
- Via the tree or the tabs. Middle-click closes a tab. Closing a tab with unsaved changes asks for confirmation.

**Find**
- ⌘F opens the bar. Type → highlights. Enter/↓ next, ⇧Enter/↑ previous. Esc closes.

**Export the active document**
- File menu → **Export PDF…** (⇧⌘E): native save dialog → writes a paginated PDF of the rendered document (reading typography, light background, no UI chrome). No print panel involved — one dialog, one file.
- File menu → **Export HTML…**: save dialog → standalone HTML file.
- File menu → **Print…** (⌘P) remains for actual printing (native panel; users can still reach "Save as PDF" there, but Export PDF is the primary path).

**Export a set of files as ZIP**
1. Select multiple files and/or folders in the explorer (⌘-click / ⇧-click), or nothing to export the whole open folder.
2. Right-click → **Export as ZIP…** (also in File menu; menu item reads "Export Folder as ZIP…" when there's no selection).
3. A small sheet confirms the scope: item count, **Preserve folder structure** (on by default), and **Include rendered HTML** (off by default — when on, each `.md` gets a sibling `.html`).
4. Native save dialog → writes the `.zip`. A brief toast/notification confirms: "ZIP exported — 14 files".
- Only `.md`/`.markdown`/`.txt` files are included; unsaved open documents prompt to save first.

---

## 10. UI components (design spec)

- **Logo / mark** — a small, minimal glyph next to the `raster` wordmark (lowercase, monospace, the "a" in amber). The mark is the one place that may carry the name's retro reference — keep it abstract and quiet. Roughly 24 px in the toolbar. **It is the only carrier of any theming.**
- **Mode switch (segmented)** — 3 options, active one with a raised background.
- **Formatting toolbar** — mono icon buttons (B, I, S, H, link, list, task, quote, code, table). Tooltips with shortcuts. Behavior follows the mode (inserts syntax in source; rich-text commands in WYSIWYG).
- **Tab bar** — tabs with a file icon, truncated name, close button; unsaved = amber dot (turns into ✕ on hover). Active tab gets a 2 px amber strip on top. Horizontal scroll with a thin scrollbar.
- **File tree** — folders with a collapsible chevron and folder icon; files with a file icon; active item with a soft amber background. Indentation per level. **Multi-select** (⌘-click / ⇧-click) with a context menu: Open, **Export as ZIP…**, Reveal in Finder.
- **ZIP export sheet** — compact native sheet: scope line ("14 files in 3 folders"), two checkboxes (Preserve folder structure — default on; Include rendered HTML — default off), Cancel / Export buttons.
- **Outline** — links per level (h1/h2/h3 with increasing indent); active section highlighted in amber with a left border (scroll-spy).
- **Callouts** — box with a colored left border by type (Note/Tip = teal; Warning/Important = amber; Caution = red), uppercase mono label with "▸".
- **Code block** — dark background (in both themes), syntax highlighting, "copy" button on hover (top-right corner).
- **Mermaid diagram** — card with panel background, centered, responsive SVG.
- **Find bar** — floating: input + counter + ↑ ↓ ✕. Current match in solid amber, others in translucent amber.
- **Status bar** — mono, discreet: ◆ RASTER · file · words · min · ln/col.
- **Preferences** — native window with theme, font, size, and language controls.

---

## 11. Visual system (tokens)

Use these values in the prototype. Two themes; both must read well.

**Colors — dark (default)**

| Token | Hex | Use |
|---|---|---|
| bg | `#14161A` | app background |
| panel | `#1B1E24` | panels, toolbar, status |
| side | `#181B20` | explorer |
| editor-bg | `#16181D` | source pane |
| code-bg | `#0F1116` | code blocks |
| border | `#2A2E37` | borders |
| ink | `#E7E5DF` | text (warm off-white, not pure white) |
| ink-strong | `#F4F2EC` | headings/bold |
| dim | `#9AA0AB` | secondary |
| **accent** | `#E0A02E` | amber: links, active states, logo, focus |
| info | `#5FB3A1` | teal (note/tip callouts) |
| danger | `#E4726B` | errors/caution |

**Colors — light**

| Token | Hex |
|---|---|
| bg | `#FCFBF8` |
| panel | `#FFFFFF` |
| side | `#F6F4EF` |
| code-bg | `#14161A` (code stays dark) |
| border | `#E5E2DB` |
| ink | `#23262C` |
| accent | `#C6871B` |
| info | `#2F8A78` |

**Typography**
- **UI / chrome:** system sans (San Francisco). Content headings also sans (weight ~650).
- **Reading body:** serif (Georgia / Iowan) — comfort for long text. Switchable to sans.
- **Editor / mono:** monospace (SF Mono / JetBrains Mono). Also used for technical labels, the status bar, and the wordmark.
- Content scale: 17 px base, 1.72 line height; h1 2em, h2 1.42em, h3 1.15em.

**Shape & space**
- Radius: 6–10 px (buttons/cards), 0 on dividers.
- 1 px hairline borders.
- Amber accent used with **restraint** — active states, focus, links, logo. No decorative amber.
- No heavy shadows; subtle elevation only on menus/floating elements.

---

## 12. Interactions & micro-interactions

- Button hover: slight background/color shift, 120–150 ms.
- Visible keyboard focus: amber outline.
- Copy button appears on code-block hover; after copying, reads "copied" in amber for ~1.3 s.
- Scroll-spy: active outline item follows the scroll position.
- Discreet transitions; **respect Reduce Motion** (no animations then).
- No showy animation on the reading surface, ever.

---

## 13. Keyboard shortcuts

| Action | Shortcut |
|---|---|
| Save | ⌘S |
| Open file | ⌘O |
| Open folder | ⇧⌘O |
| New file | ⌘N |
| Find in document | ⌘F |
| Next / previous match | ↓ / ↑ (in find) |
| Bold / Italic / Link | ⌘B / ⌘I / ⌘K |
| Toggle explorer | ⌘\ |
| Editor / Split / Reading mode | ⌘1 / ⌘2 / ⌘3 |
| Toggle Read/Edit (in Reading) | ⌘E |
| Close tab | ⌘W |
| Next / previous tab | ⌃Tab / ⌃⇧Tab |
| Export PDF | ⇧⌘E |
| Print | ⌘P |
| Preferences | ⌘, |

---

## 14. Languages (English and Brazilian Portuguese)

The app is fully localized in **English** and **Brazilian Portuguese**. This covers the entire interface — menus, toolbar, tooltips, dialogs, preferences, empty states, error messages, callout labels, and the sample document — but **never the user's content**, which is displayed as-is.

**Behavior:**
- **Default: follow the system language** (macOS). System in pt-BR → pt-BR; anything else → English (fallback).
- **Manual override in Preferences:** System (default) · English · Português (Brasil). The switch applies without a restart (or with a restart prompt if the platform requires it — an implementation decision, but the design should assume a live switch).
- On macOS, users can also set a per-app language in System Settings › General › Language & Region — the app respects that automatically.

**Content vs. interface rules:**
- The user's Markdown is never translated or altered.
- **Callout labels** (`[!NOTE]` → "Note"/"Nota" etc.) are interface, so they localize: the *syntax* in the file stays English (GFM standard), the *rendered label* follows the UI language.
- The **sample document** (`read-me.md` / `leia-me.md`) exists in both languages; the one matching the active UI loads.
- **Stats** localize ("842 words · 4 min" / "842 palavras · 4 min").
- Dates/numbers in dialogs follow the system locale.

**Design notes (important for the prototype):**
- English strings tend to be shorter; Portuguese runs ~20–30% longer. Buttons, tabs, segmented controls, and menus must fit the longer version without truncation — size for pt-BR.
- The mode switch is the most sensitive case: **Editor · Split · Reading** vs **Editor · Dividido · Leitura**.
- Keyboard shortcuts don't change between languages.
- The brand (`raster`, wordmark, logo) and established terms (Markdown, Mermaid) don't translate.

**Reference microcopy (main pairs):**

| en | pt-BR |
|---|---|
| Editor · Split · Reading | Editor · Dividido · Leitura |
| Edit / Editing | Editar / Editando |
| Open Folder / Open File | Abrir pasta / Abrir arquivo |
| Save / Export HTML / Print | Salvar / Exportar HTML / Imprimir |
| Export PDF… / Export as ZIP… | Exportar PDF… / Exportar como ZIP… |
| Preserve folder structure / Include rendered HTML | Preservar estrutura de pastas / Incluir HTML renderizado |
| ZIP exported — X files | ZIP exportado — X arquivos |
| Files / Outline | Arquivos / Tópicos |
| Find in document | Buscar no documento |
| copy / copied | copiar / copiado |
| Note · Tip · Warning · Important · Caution | Nota · Dica · Atenção · Importante · Cuidado |
| editing — code and diagrams locked | editando — código e diagramas travados |
| No headings. / No folder open. | Sem títulos. / Nenhuma pasta aberta. |
| Discard unsaved changes? | Descartar alterações não salvas? |
| X words · Y min | X palavras · Y min |

---

## 15. Accessibility & non-functional requirements

- AA contrast in both themes (text on background, amber on dark).
- Full keyboard navigation; visible focus.
- Respect **Reduce Motion** and the user's system font-size settings.
- **Offline-first**: zero runtime network dependency.
- **File safety**: atomic writes; confirmation when closing unsaved work; no work lost when switching tabs/modes.
- Performance: typical documents open and render instantly; typing stays fluid (debounced render).

---

## 16. Roadmap (post-v1)

- Editor↔preview scroll sync.
- Wiki-links between files and whole-folder search.
- Presentation mode (split on `---`).
- Autosave and local history.
- Quick Look / Finder integration.
- iOS/iPadOS version.
