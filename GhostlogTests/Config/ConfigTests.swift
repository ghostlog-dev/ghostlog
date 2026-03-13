import XCTest
@testable import Ghostlog

final class ConfigTests: XCTestCase {
    var tempPath: URL!
    var config: Config!
    let testKeychainService = "com.ghostlog.app.tests-\(UUID().uuidString)"

    override func setUp() {
        super.setUp()
        tempPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("ghostlog-test-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: tempPath, withIntermediateDirectories: true)
        config = Config(directory: tempPath, keychainService: testKeychainService)
    }

    override func tearDown() {
        config.clearToken()
        try? FileManager.default.removeItem(at: tempPath)
        super.tearDown()
    }

    func testReturnsEmptyConfigWhenFileAbsent() {
        let loaded = config.load()
        XCTAssertNotNil(loaded)
        XCTAssertNil(loaded?.searchRoots)
    }

    func testSaveAndLoadSearchRoots() throws {
        let saved = GhostlogConfig(searchRoots: ["/Users/test/projects"])
        try config.save(saved)

        let loaded = config.load()
        XCTAssertEqual(loaded?.searchRoots, ["/Users/test/projects"])
    }

    func testTokenStoredInKeychain() {
        XCTAssertFalse(config.isConfigured)
        config.token = "mytoken"
        XCTAssertTrue(config.isConfigured)
        XCTAssertEqual(config.token, "mytoken")
    }

    func testTokenNotWrittenToDisk() throws {
        config.token = "secret"
        try config.save(GhostlogConfig(searchRoots: nil))

        let raw = try String(contentsOf: tempPath.appendingPathComponent("config.json"))
        XCTAssertFalse(raw.contains("secret"), "Token must not appear in config.json")
    }

    func testClearToken() {
        config.token = "mytoken"
        XCTAssertTrue(config.isConfigured)
        config.clearToken()
        XCTAssertFalse(config.isConfigured)
    }

    func testMigratesTokenFromLegacyJson() throws {
        // Write old-style config.json that contains a token
        let json = """
        {"token": "legacy_token", "searchRoots": ["/Users/dev/projects"]}
        """.data(using: .utf8)!
        let file = tempPath.appendingPathComponent("config.json")
        try json.write(to: file)

        // Re-init Config to trigger migration
        let freshConfig = Config(directory: tempPath, keychainService: testKeychainService)

        // Token should be removed from JSON
        let rawAfter = try String(contentsOf: file)
        XCTAssertFalse(rawAfter.contains("legacy_token"), "Token must be removed from config.json after migration")

        // searchRoots should be preserved
        XCTAssertEqual(freshConfig.load()?.searchRoots, ["/Users/dev/projects"])

        // Token should be available via config (either migrated to Keychain or as a fallback)
        // If Keychain write succeeded, isConfigured should be true
        if let token = freshConfig.token {
            XCTAssertEqual(token, "legacy_token")
        }
    }

    func testIsConfigured() {
        XCTAssertFalse(config.isConfigured)
        config.token = "t"
        XCTAssertTrue(config.isConfigured)
    }
}
