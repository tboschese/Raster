import XCTest
import ZIPFoundation
@testable import Raster

final class ExportServiceZIPTests: XCTestCase {
    private nonisolated(unsafe) var workDirectory: URL!

    override func setUpWithError() throws {
        workDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fm = FileManager.default
        try fm.createDirectory(at: workDirectory.appendingPathComponent("docs"), withIntermediateDirectories: true)
        try fm.createDirectory(at: workDirectory.appendingPathComponent("notes"), withIntermediateDirectories: true)
        try "# Architecture".write(to: workDirectory.appendingPathComponent("docs/architecture.md"), atomically: true, encoding: .utf8)
        try "# Roadmap".write(to: workDirectory.appendingPathComponent("notes/roadmap.md"), atomically: true, encoding: .utf8)
        try "# Roadmap (duplicate name)".write(to: workDirectory.appendingPathComponent("docs/roadmap.md"), atomically: true, encoding: .utf8)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: workDirectory)
    }

    private var items: [ZipExportItem] {
        [
            ZipExportItem(relativePath: "docs/architecture.md", sourceURL: workDirectory.appendingPathComponent("docs/architecture.md")),
            ZipExportItem(relativePath: "notes/roadmap.md", sourceURL: workDirectory.appendingPathComponent("notes/roadmap.md")),
            ZipExportItem(relativePath: "docs/roadmap.md", sourceURL: workDirectory.appendingPathComponent("docs/roadmap.md")),
        ]
    }

    private func entryPaths(in zipURL: URL) throws -> Set<String> {
        let archive = try Archive(url: zipURL, accessMode: .read)
        return Set(archive.map(\.path))
    }

    func testPreservesStructureByDefault() async throws {
        let destination = workDirectory.appendingPathComponent("preserved.zip")
        let options = ZipExportOptions(preserveStructure: true, includeRenderedHTML: false)
        let summary = try await ExportService.exportZIP(items: items, options: options, language: "en", to: destination)

        XCTAssertEqual(summary.exportedCount, 3)
        XCTAssertEqual(try entryPaths(in: destination), ["docs/architecture.md", "notes/roadmap.md", "docs/roadmap.md"])
    }

    func testFlattenedStructureSuffixesNameCollisions() async throws {
        let destination = workDirectory.appendingPathComponent("flattened.zip")
        let options = ZipExportOptions(preserveStructure: false, includeRenderedHTML: false)
        let summary = try await ExportService.exportZIP(items: items, options: options, language: "en", to: destination)

        XCTAssertEqual(summary.exportedCount, 3)
        let paths = try entryPaths(in: destination)
        XCTAssertTrue(paths.contains("architecture.md"))
        XCTAssertTrue(paths.contains("roadmap.md"))
        XCTAssertTrue(paths.contains("roadmap-1.md"))
        XCTAssertEqual(paths.count, 3)
    }

    func testSkipsUnreadableFilesWithoutAbortingTheWholeArchive() async throws {
        let destination = workDirectory.appendingPathComponent("partial.zip")
        let missing = ZipExportItem(relativePath: "missing.md", sourceURL: workDirectory.appendingPathComponent("missing.md"))
        let options = ZipExportOptions(preserveStructure: true, includeRenderedHTML: false)
        let summary = try await ExportService.exportZIP(items: items + [missing], options: options, language: "en", to: destination)

        XCTAssertEqual(summary.exportedCount, 3)
        XCTAssertEqual(summary.skipped.count, 1)
        XCTAssertEqual(summary.skipped.first?.name, "missing.md")
    }
}
