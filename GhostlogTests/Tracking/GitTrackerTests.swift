import XCTest
@testable import Ghostlog

final class GitTrackerTests: XCTestCase {
    var tempDir: URL!
    var tracker: GitTracker!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gittracker-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        tracker = GitTracker()
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testFindsExactMatch() {
        let projectDir = tempDir.appendingPathComponent("my-project")
        let gitDir = projectDir.appendingPathComponent(".git")
        try! FileManager.default.createDirectory(at: gitDir, withIntermediateDirectories: true)

        let result = tracker.resolveProjectPath(basename: "my-project", searchRoots: [tempDir.path])
        XCTAssertEqual(result, projectDir.path)
    }

    func testFindsOneDepthDeeper() {
        let clientDir = tempDir.appendingPathComponent("client")
        let projectDir = clientDir.appendingPathComponent("deep-project")
        let gitDir = projectDir.appendingPathComponent(".git")
        try! FileManager.default.createDirectory(at: gitDir, withIntermediateDirectories: true)

        let result = tracker.resolveProjectPath(basename: "deep-project", searchRoots: [tempDir.path])
        XCTAssertEqual(result, projectDir.path)
    }

    func testPrefersGitRepoOverPlainDirectory() {
        // Plain dir in root
        let plain = tempDir.appendingPathComponent("my-app")
        try! FileManager.default.createDirectory(at: plain, withIntermediateDirectories: true)

        // Git repo one level deeper
        let nested = tempDir.appendingPathComponent("client").appendingPathComponent("my-app")
        try! FileManager.default.createDirectory(at: nested.appendingPathComponent(".git"), withIntermediateDirectories: true)

        let result = tracker.resolveProjectPath(basename: "my-app", searchRoots: [tempDir.path])
        XCTAssertEqual(result, nested.path)
    }

    func testReturnsNilWhenNotFound() {
        let result = tracker.resolveProjectPath(basename: "nonexistent", searchRoots: [tempDir.path])
        XCTAssertNil(result)
    }

    func testCaseInsensitiveMatch() {
        let projectDir = tempDir.appendingPathComponent("MyProject")
        let gitDir = projectDir.appendingPathComponent(".git")
        try! FileManager.default.createDirectory(at: gitDir, withIntermediateDirectories: true)

        let result = tracker.resolveProjectPath(basename: "myproject", searchRoots: [tempDir.path])
        XCTAssertEqual(result, projectDir.path)
    }
}
