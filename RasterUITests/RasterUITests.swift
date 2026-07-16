import XCTest

/// End-to-end UI smoke tests — see CLAUDE.md "Tests & Definition of Done".
/// Exercises the sample document Raster opens on first launch rather than a
/// real folder, so these don't depend on fixture files on disk.
final class RasterUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    func testLaunchesWithSampleDocumentOpen() throws {
        XCTAssertTrue(app.staticTexts["RASTER"].waitForExistence(timeout: 5))
    }

    func testSwitchingModesTogglesPanes() throws {
        app.buttons["Editor"].click()
        app.buttons["Split"].click()
        app.buttons["Reading"].click()
        XCTAssertTrue(app.buttons["Read"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Edit"].exists)
    }

    func testToggleExplorerHidesSidebar() throws {
        let sidebar = app.groups["Explorer"]
        let wasVisible = sidebar.exists
        app.typeKey("\\", modifierFlags: .command)
        if wasVisible {
            XCTAssertFalse(sidebar.waitForExistence(timeout: 2))
        }
    }

    func testFindOpensAndClosesWithEscape() throws {
        app.typeKey("f", modifierFlags: .command)
        XCTAssertTrue(app.textFields["Find in document"].waitForExistence(timeout: 2))
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertFalse(app.textFields["Find in document"].waitForExistence(timeout: 1))
    }
}
