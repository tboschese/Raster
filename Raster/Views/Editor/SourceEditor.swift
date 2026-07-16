import AppKit
import SwiftUI

/// Wraps `NSTextView` for the Markdown source pane (Editor/Split modes).
/// `TextEditor` isn't used — CLAUDE.md requires the finer control `NSTextView`
/// gives us over tab handling, selection reporting, and highlighting.
struct SourceEditor: NSViewRepresentable {
    @Binding var text: String
    var theme: Theme
    var pendingSelection: NSRange?
    var onSelectionChange: (NSRange) -> Void
    var onCursorPositionChange: (_ line: Int, _ column: Int) -> Void
    var onConsumePendingSelection: () -> Void

    static var baseFont: NSFont { NSFont.monospacedSystemFont(ofSize: 13.5, weight: .regular) }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.allowsUndo = true
        textView.font = Self.baseFont
        textView.textContainerInset = NSSize(width: 22, height: 20)
        textView.string = text
        textView.drawsBackground = false
        textView.isEditable = true
        textView.textContainer?.widthTracksTextView = true
        textView.autoresizingMask = [.width]

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.autohidesScrollers = true

        context.coordinator.textView = textView
        if let storage = textView.textStorage {
            MarkdownHighlighter.apply(to: storage, theme: theme, baseFont: Self.baseFont)
        }
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = context.coordinator.textView, let storage = textView.textStorage else { return }

        if textView.string != text {
            let selectedRanges = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selectedRanges
            MarkdownHighlighter.apply(to: storage, theme: theme, baseFont: Self.baseFont)
        } else if context.coordinator.lastTheme != theme {
            MarkdownHighlighter.apply(to: storage, theme: theme, baseFont: Self.baseFont)
        }
        context.coordinator.lastTheme = theme

        if let pendingSelection {
            textView.setSelectedRange(pendingSelection)
            textView.scrollRangeToVisible(pendingSelection)
            DispatchQueue.main.async { onConsumePendingSelection() }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: SourceEditor
        weak var textView: NSTextView?
        var lastTheme: Theme

        init(_ parent: SourceEditor) {
            self.parent = parent
            self.lastTheme = parent.theme
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            if let storage = textView.textStorage {
                MarkdownHighlighter.apply(to: storage, theme: parent.theme, baseFont: SourceEditor.baseFont)
            }
            reportSelection(textView)
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            reportSelection(textView)
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertTab(_:)) {
                textView.insertText("  ", replacementRange: textView.selectedRange())
                return true
            }
            return false
        }

        private func reportSelection(_ textView: NSTextView) {
            let range = textView.selectedRange()
            parent.onSelectionChange(range)
            let ns = textView.string as NSString
            let prefix = ns.substring(to: min(range.location, ns.length))
            let lines = prefix.components(separatedBy: "\n")
            let line = lines.count
            let column = (lines.last?.count ?? 0) + 1
            parent.onCursorPositionChange(line, column)
        }
    }
}
