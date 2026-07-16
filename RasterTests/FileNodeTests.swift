import XCTest
@testable import Raster

final class FileNodeTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fm = FileManager.default
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        try fm.createDirectory(at: root.appendingPathComponent("docs"), withIntermediateDirectories: true)
        fm.createFile(atPath: root.appendingPathComponent("docs/architecture.md").path, contents: Data("# Architecture".utf8))
        fm.createFile(atPath: root.appendingPathComponent("read-me.md").path, contents: Data("# Read me".utf8))
        fm.createFile(atPath: root.appendingPathComponent("image.png").path, contents: Data())
        fm.createFile(atPath: root.appendingPathComponent(".hidden.md").path, contents: Data())
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    func testBuildTreeSkipsHiddenAndNonMarkdownFiles() {
        let node = FileNode.buildTree(at: root)
        let names = (node.children ?? []).map(\.name)
        XCTAssertTrue(names.contains("docs"))
        XCTAssertTrue(names.contains("read-me.md"))
        XCTAssertFalse(names.contains("image.png"))
        XCTAssertFalse(names.contains(".hidden.md"))
    }

    func testBuildTreeSortsDirectoriesBeforeFiles() {
        let node = FileNode.buildTree(at: root)
        let children = node.children ?? []
        guard let docsIndex = children.firstIndex(where: { $0.name == "docs" }),
              let readMeIndex = children.firstIndex(where: { $0.name == "read-me.md" }) else {
            return XCTFail("Expected both docs/ and read-me.md")
        }
        XCTAssertLessThan(docsIndex, readMeIndex)
    }

    func testBuildTreeRecursesIntoDirectories() {
        let node = FileNode.buildTree(at: root)
        guard let docs = node.children?.first(where: { $0.name == "docs" }) else {
            return XCTFail("Expected docs/ node")
        }
        XCTAssertEqual(docs.children?.map(\.name), ["architecture.md"])
    }
}
