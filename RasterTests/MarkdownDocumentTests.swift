import XCTest
@testable import Raster

final class MarkdownDocumentTests: XCTestCase {
    func testNewDocumentIsNotDirty() {
        let document = MarkdownDocument(name: "note.md", content: "# Hello")
        XCTAssertFalse(document.isDirty)
    }

    func testEditingMakesDocumentDirty() {
        var document = MarkdownDocument(name: "note.md", content: "# Hello")
        document.content = "# Hello, world"
        XCTAssertTrue(document.isDirty)
    }

    func testMarkSavedClearsDirtyState() {
        var document = MarkdownDocument(name: "note.md", content: "# Hello")
        document.content = "# Hello, world"
        document.markSaved()
        XCTAssertFalse(document.isDirty)
    }

    func testRevertToSavedRestoresOriginalContent() {
        var document = MarkdownDocument(name: "note.md", content: "# Hello")
        document.markSaved()
        document.content = "# Something else entirely"
        document.revertToSaved()
        XCTAssertEqual(document.content, "# Hello")
        XCTAssertFalse(document.isDirty)
    }
}
