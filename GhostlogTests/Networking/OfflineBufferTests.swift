import XCTest
@testable import Ghostlog

final class OfflineBufferTests: XCTestCase {
    var tempDir: URL!
    var buffer: OfflineBuffer!

    private func makeHeartbeat(_ app: String) -> Heartbeat {
        Heartbeat(recordedAt: "2026-01-01T00:00:00Z", appName: app,
                  windowTitle: "", ideProject: nil, gitRemote: nil,
                  gitBranch: nil, browserUrl: nil, isIdle: false, idleSeconds: 0)
    }

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("buffer-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        buffer = OfflineBuffer(directory: tempDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testEmptyByDefault() {
        XCTAssertTrue(buffer.read().isEmpty)
    }

    func testAppendAndRead() {
        buffer.append(makeHeartbeat("PhpStorm"))
        buffer.append(makeHeartbeat("Safari"))
        let items = buffer.read()
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].appName, "PhpStorm")
        XCTAssertEqual(items[1].appName, "Safari")
    }

    func testClear() {
        buffer.append(makeHeartbeat("Xcode"))
        buffer.clear()
        XCTAssertTrue(buffer.read().isEmpty)
    }
}
