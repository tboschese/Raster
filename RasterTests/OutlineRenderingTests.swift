import XCTest
@testable import Raster

/// Exercises the real WebCore engine (marked + our renderer overrides) end to
/// end through `OffscreenRenderer`, the same path `ExportService` uses. This
/// target's "Host Application" must be set to Raster so `Bundle.main`
/// resolves to the app bundle and finds `WebCore/` — see CLAUDE.md
/// "WKWebView + file://".
@MainActor
final class OutlineRenderingTests: XCTestCase {
    private let sample = """
    # Title

    ## First section

    Some text with a [link](https://example.com).

    ## Second section

    - [ ] todo one
    - [x] todo two
    """

    func testOutlineExtractionAndStats() async throws {
        let renderer = OffscreenRenderer()
        try await renderer.prepare(frame: CGRect(x: 0, y: 0, width: 800, height: 1000))

        let outline = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[OutlineEntry], Error>) in
            renderer.bridge.onUpdateOutline = { entries in
                continuation.resume(returning: entries)
            }
            renderer.bridge.setContent(sample)
        }

        XCTAssertEqual(outline.map(\.title), ["Title", "First section", "Second section"])
        XCTAssertEqual(outline.map(\.level), [1, 2, 2])
    }

    func testStatsReportWordCount() async throws {
        let renderer = OffscreenRenderer()
        try await renderer.prepare(frame: CGRect(x: 0, y: 0, width: 800, height: 1000))

        let stats = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<DocumentStats, Error>) in
            renderer.bridge.onUpdateStats = { stats in
                continuation.resume(returning: stats)
            }
            renderer.bridge.setContent(sample)
        }

        XCTAssertGreaterThan(stats.words, 0)
        XCTAssertGreaterThanOrEqual(stats.readingMinutes, 1)
    }
}
