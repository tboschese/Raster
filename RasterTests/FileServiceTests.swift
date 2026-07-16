import XCTest
@testable import Raster

final class FileServiceTests: XCTestCase {
    private nonisolated(unsafe) var tempDirectory: URL!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    func testWriteThenReadRoundTrips() async throws {
        let url = tempDirectory.appendingPathComponent("note.md")
        try await FileService.write("# Hello, Raster", to: url)
        let readBack = try await FileService.readFile(at: url)
        XCTAssertEqual(readBack, "# Hello, Raster")
    }

    func testWriteIsAtomicAndOverwrites() async throws {
        let url = tempDirectory.appendingPathComponent("note.md")
        try await FileService.write("first", to: url)
        try await FileService.write("second", to: url)
        let readBack = try await FileService.readFile(at: url)
        XCTAssertEqual(readBack, "second")
    }

    func testReadMissingFileThrows() async {
        let url = tempDirectory.appendingPathComponent("missing.md")
        do {
            _ = try await FileService.readFile(at: url)
            XCTFail("Expected a read failure")
        } catch {
            XCTAssertTrue(error is RasterError)
        }
    }

    @MainActor
    func testBookmarkRoundTrips() throws {
        let url = tempDirectory.appendingPathComponent("bookmarked.md")
        FileManager.default.createFile(atPath: url.path, contents: Data("x".utf8))
        let bookmark = try FileService.makeBookmark(for: url)
        let resolved = try FileService.resolveBookmark(bookmark)
        XCTAssertEqual(resolved.url.standardizedFileURL.path, url.standardizedFileURL.path)
    }
}
