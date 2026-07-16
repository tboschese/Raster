import AppKit

/// Lightweight, regex-based Markdown syntax highlighting for the source
/// editor. Not a full parser — good enough to make structure scannable
/// (headings, emphasis, code, links, blockquotes, fenced code) without the
/// cost of a real incremental parser.
enum MarkdownHighlighter {
    struct Palette {
        var heading: NSColor
        var body: NSColor
        var code: NSColor
        var codeBackground: NSColor
        var link: NSColor
        var dim: NSColor

        static func palette(for theme: Theme) -> Palette {
            switch theme {
            case .dark:
                return Palette(
                    heading: NSColor(srgbRed: 0.957, green: 0.949, blue: 0.925, alpha: 1),
                    body: NSColor(srgbRed: 0.906, green: 0.898, blue: 0.875, alpha: 1),
                    code: NSColor(srgbRed: 0.839, green: 0.855, blue: 0.875, alpha: 1),
                    codeBackground: NSColor.white.withAlphaComponent(0.06),
                    link: NSColor(srgbRed: 0.878, green: 0.627, blue: 0.180, alpha: 1),
                    dim: NSColor(srgbRed: 0.604, green: 0.627, blue: 0.671, alpha: 1)
                )
            case .light:
                return Palette(
                    heading: NSColor(srgbRed: 0.067, green: 0.078, blue: 0.094, alpha: 1),
                    body: NSColor(srgbRed: 0.137, green: 0.149, blue: 0.173, alpha: 1),
                    code: NSColor(srgbRed: 0.137, green: 0.149, blue: 0.173, alpha: 1),
                    codeBackground: NSColor.black.withAlphaComponent(0.045),
                    link: NSColor(srgbRed: 0.776, green: 0.529, blue: 0.106, alpha: 1),
                    dim: NSColor(srgbRed: 0.478, green: 0.502, blue: 0.537, alpha: 1)
                )
            }
        }
    }

    static func apply(to textStorage: NSTextStorage, theme: Theme, baseFont: NSFont) {
        let palette = Palette.palette(for: theme)
        let text = textStorage.string as NSString
        let fullRange = NSRange(location: 0, length: text.length)
        guard fullRange.length > 0 else { return }

        textStorage.beginEditing()
        textStorage.setAttributes([.font: baseFont, .foregroundColor: palette.body], range: fullRange)

        var inFence = false
        text.enumerateSubstrings(in: fullRange, options: .byLines) { _, lineRange, _, _ in
            let line = text.substring(with: lineRange)
            if line.range(of: "^```", options: .regularExpression) != nil {
                inFence.toggle()
                textStorage.addAttribute(.foregroundColor, value: palette.dim, range: lineRange)
                return
            }
            if inFence {
                textStorage.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: baseFont.pointSize, weight: .regular), range: lineRange)
                textStorage.addAttribute(.foregroundColor, value: palette.code, range: lineRange)
                return
            }
            if line.range(of: "^#{1,6} ", options: .regularExpression) != nil {
                textStorage.addAttribute(.font, value: NSFont.systemFont(ofSize: baseFont.pointSize + 2, weight: .semibold), range: lineRange)
                textStorage.addAttribute(.foregroundColor, value: palette.heading, range: lineRange)
                return
            }
            if line.hasPrefix(">") {
                textStorage.addAttribute(.foregroundColor, value: palette.dim, range: lineRange)
            }
            if line.range(of: "^(-{3,}|\\*{3,}|_{3,})\\s*$", options: .regularExpression) != nil {
                textStorage.addAttribute(.foregroundColor, value: palette.dim, range: lineRange)
            }
        }

        applyPattern("\\*\\*[^*\\n]+\\*\\*", in: text) { range in
            textStorage.addAttribute(.font, value: NSFont.boldSystemFont(ofSize: baseFont.pointSize), range: range)
        }
        applyPattern("(?<!\\*)\\*[^*\\n]+\\*(?!\\*)", in: text) { range in
            let italic = NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask)
            textStorage.addAttribute(.font, value: italic, range: range)
        }
        applyPattern("`[^`\\n]+`", in: text) { range in
            textStorage.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: max(10, baseFont.pointSize - 1), weight: .regular), range: range)
            textStorage.addAttribute(.foregroundColor, value: palette.code, range: range)
            textStorage.addAttribute(.backgroundColor, value: palette.codeBackground, range: range)
        }
        applyPattern("\\[[^\\]\\n]*\\]\\([^)\\n]*\\)", in: text) { range in
            textStorage.addAttribute(.foregroundColor, value: palette.link, range: range)
        }

        textStorage.endEditing()
    }

    private static func applyPattern(_ pattern: String, in text: NSString, apply: (NSRange) -> Void) {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        let fullRange = NSRange(location: 0, length: text.length)
        regex.enumerateMatches(in: text as String, range: fullRange) { match, _, _ in
            guard let match else { return }
            apply(match.range)
        }
    }
}
