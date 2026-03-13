import XCTest
@testable import Ghostlog

final class GitHookManagerTests: XCTestCase {
    var tempDir: URL!
    var manager: GitHookManager!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("hooks-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        manager = GitHookManager(hooksDirectory: tempDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testInstallWritesExecutableScript() throws {
        try manager.install(apiUrl: "https://api.example.com", token: "mytoken")
        let hookPath = tempDir.appendingPathComponent("post-commit")
        XCTAssertTrue(FileManager.default.fileExists(atPath: hookPath.path))

        let content = try String(contentsOf: hookPath)
        XCTAssertTrue(content.contains("ghostlog-hook"))
        XCTAssertTrue(content.contains("https://api.example.com"))
        XCTAssertTrue(content.contains("mytoken"))
        XCTAssertTrue(content.contains("curl"))

        let attrs = try FileManager.default.attributesOfItem(atPath: hookPath.path)
        let perms = attrs[.posixPermissions] as? Int
        XCTAssertEqual(perms, 0o755)
    }

    func testUninstallRemovesScript() throws {
        try manager.install(apiUrl: "https://api.example.com", token: "mytoken")
        manager.uninstall()
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: tempDir.appendingPathComponent("post-commit").path
        ))
    }

    func testIsInstalledReflectsState() throws {
        XCTAssertFalse(manager.isInstalled)
        try manager.install(apiUrl: "https://api.example.com", token: "t")
        XCTAssertTrue(manager.isInstalled)
        manager.uninstall()
        XCTAssertFalse(manager.isInstalled)
    }
}
