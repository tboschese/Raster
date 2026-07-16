import Foundation

enum FormatCommand: String, CaseIterable, Identifiable {
    case bold, italic, strikethrough, heading, link, list, task, quote, codeBlock, table

    var id: String { rawValue }
}

struct TextEdit {
    var text: String
    var selection: NSRange
}

/// Pure text-transformation logic behind the Format toolbar / menu: given the
/// source Markdown and the editor's current selection, returns the edited
/// text and where the selection should land afterward. Side-effect free so
/// it's directly unit-testable — see RasterTests/TextFormatterTests.swift.
enum TextFormatter {
    static func apply(_ command: FormatCommand, to text: String, selection: NSRange) -> TextEdit {
        switch command {
        case .bold: return toggleInline(text, selection, marker: "**")
        case .italic: return toggleInline(text, selection, marker: "*")
        case .strikethrough: return toggleInline(text, selection, marker: "~~")
        case .heading: return toggleLinePrefix(text, selection, addPrefix: "## ", detectPattern: "^#{1,6} ")
        case .list: return toggleLinePrefix(text, selection, addPrefix: "- ", detectPattern: "^[-*+] ")
        case .task: return toggleLinePrefix(text, selection, addPrefix: "- [ ] ", detectPattern: "^- \\[[ xX]\\] ")
        case .quote: return toggleLinePrefix(text, selection, addPrefix: "> ", detectPattern: "^> ")
        case .link: return wrapSelection(text, selection, before: "[", after: "](url)")
        case .codeBlock: return wrapSelection(text, selection, before: "\n```\n", after: "\n```\n")
        case .table: return insertAtCursor(text, selection, insertion: "\n| A | B |\n|---|---|\n|  |  |\n")
        }
    }

    // MARK: - Primitives (NSRange/NSString throughout to match NSTextView's coordinate space)

    private static func clampedRange(_ range: NSRange, in ns: NSString) -> NSRange {
        let location = max(0, min(range.location, ns.length))
        let length = max(0, min(range.length, ns.length - location))
        return NSRange(location: location, length: length)
    }

    private static func wrapSelection(_ text: String, _ selection: NSRange, before: String, after: String) -> TextEdit {
        let ns = text as NSString
        let range = clampedRange(selection, in: ns)
        let selected = ns.substring(with: range)
        let newText = ns.replacingCharacters(in: range, with: before + selected + after)
        let newStart = range.location + (before as NSString).length
        return TextEdit(text: newText, selection: NSRange(location: newStart, length: (selected as NSString).length))
    }

    private static func insertAtCursor(_ text: String, _ selection: NSRange, insertion: String) -> TextEdit {
        let ns = text as NSString
        let range = clampedRange(selection, in: ns)
        let newText = ns.replacingCharacters(in: range, with: insertion)
        let newLocation = range.location + (insertion as NSString).length
        return TextEdit(text: newText, selection: NSRange(location: newLocation, length: 0))
    }

    /// Wraps `selection` in `marker` on both sides, or removes it if the
    /// selection is already exactly surrounded by `marker`.
    private static func toggleInline(_ text: String, _ selection: NSRange, marker: String) -> TextEdit {
        let ns = text as NSString
        let range = clampedRange(selection, in: ns)
        let markerLen = (marker as NSString).length
        if range.location >= markerLen, range.location + range.length + markerLen <= ns.length {
            let before = ns.substring(with: NSRange(location: range.location - markerLen, length: markerLen))
            let after = ns.substring(with: NSRange(location: range.location + range.length, length: markerLen))
            if before == marker, after == marker {
                let outerRange = NSRange(location: range.location - markerLen, length: range.length + 2 * markerLen)
                let inner = ns.substring(with: range)
                let newText = ns.replacingCharacters(in: outerRange, with: inner)
                return TextEdit(text: newText, selection: NSRange(location: range.location - markerLen, length: range.length))
            }
        }
        return wrapSelection(text, range, before: marker, after: marker)
    }

    /// Toggles a line-leading marker (heading/list/task/quote) on the line
    /// containing the selection's start.
    private static func toggleLinePrefix(_ text: String, _ selection: NSRange, addPrefix: String, detectPattern: String) -> TextEdit {
        let ns = text as NSString
        let range = clampedRange(selection, in: ns)
        let lineRange = ns.lineRange(for: NSRange(location: range.location, length: 0))
        let line = ns.substring(with: lineRange)
        if let match = line.range(of: detectPattern, options: .regularExpression), match.lowerBound == line.startIndex {
            let matched = String(line[match])
            let stripped = String(line[match.upperBound...])
            let newText = ns.replacingCharacters(in: lineRange, with: stripped)
            let delta = (matched as NSString).length
            let newLocation = max(lineRange.location, range.location - delta)
            return TextEdit(text: newText, selection: NSRange(location: newLocation, length: range.length))
        }
        let newLine = addPrefix + line
        let newText = ns.replacingCharacters(in: lineRange, with: newLine)
        let delta = (addPrefix as NSString).length
        return TextEdit(text: newText, selection: NSRange(location: range.location + delta, length: range.length))
    }
}
