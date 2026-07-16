import XCTest
@testable import Raster

final class TextFormatterTests: XCTestCase {
    func testBoldWrapsSelection() {
        let edit = TextFormatter.apply(.bold, to: "hello world", selection: NSRange(location: 0, length: 5))
        XCTAssertEqual(edit.text, "**hello** world")
        XCTAssertEqual(edit.selection, NSRange(location: 2, length: 5))
    }

    func testBoldTwiceUnwraps() {
        let first = TextFormatter.apply(.bold, to: "hello world", selection: NSRange(location: 0, length: 5))
        let second = TextFormatter.apply(.bold, to: first.text, selection: first.selection)
        XCTAssertEqual(second.text, "hello world")
    }

    func testItalicWrapsSelection() {
        let edit = TextFormatter.apply(.italic, to: "hello", selection: NSRange(location: 0, length: 5))
        XCTAssertEqual(edit.text, "*hello*")
    }

    func testHeadingAddsPrefixToLine() {
        let edit = TextFormatter.apply(.heading, to: "Title", selection: NSRange(location: 0, length: 0))
        XCTAssertEqual(edit.text, "## Title")
    }

    func testHeadingTogglesOffExistingHeading() {
        let edit = TextFormatter.apply(.heading, to: "### Title", selection: NSRange(location: 4, length: 0))
        XCTAssertEqual(edit.text, "Title")
    }

    func testTaskAddsCheckboxPrefix() {
        let edit = TextFormatter.apply(.task, to: "buy milk", selection: NSRange(location: 0, length: 0))
        XCTAssertEqual(edit.text, "- [ ] buy milk")
    }

    func testTaskTogglesOffExistingTask() {
        let edit = TextFormatter.apply(.task, to: "- [x] buy milk", selection: NSRange(location: 0, length: 0))
        XCTAssertEqual(edit.text, "buy milk")
    }

    func testQuoteTogglesLine() {
        let on = TextFormatter.apply(.quote, to: "a thought", selection: NSRange(location: 0, length: 0))
        XCTAssertEqual(on.text, "> a thought")
        let off = TextFormatter.apply(.quote, to: on.text, selection: NSRange(location: 0, length: 0))
        XCTAssertEqual(off.text, "a thought")
    }

    func testLinkWrapsSelectionWithURLPlaceholder() {
        let edit = TextFormatter.apply(.link, to: "Raster", selection: NSRange(location: 0, length: 6))
        XCTAssertEqual(edit.text, "[Raster](url)")
    }

    func testTableInsertsAtCursor() {
        let edit = TextFormatter.apply(.table, to: "", selection: NSRange(location: 0, length: 0))
        XCTAssertTrue(edit.text.contains("| A | B |"))
    }
}
