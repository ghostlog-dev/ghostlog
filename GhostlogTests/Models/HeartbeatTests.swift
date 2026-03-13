import XCTest
@testable import Ghostlog

final class HeartbeatTests: XCTestCase {
    func testEncodesWithSnakeCaseKeys() throws {
        let h = Heartbeat(
            recordedAt: "2026-01-01T00:00:00Z",
            appName: "PhpStorm",
            windowTitle: "project – file – PhpStorm",
            ideProject: "project",
            gitRemote: "github.com/org/project",
            gitBranch: "main",
            browserUrl: nil,
            isIdle: false,
            idleSeconds: 0
        )
        let data = try JSONEncoder().encode(h)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertNotNil(json["recorded_at"])
        XCTAssertNotNil(json["app_name"])
        XCTAssertNotNil(json["window_title"])
        XCTAssertNotNil(json["is_idle"])
        XCTAssertNil(json["browserUrl"]) // must not use camelCase
    }

    func testDecodesFromSnakeCaseKeys() throws {
        let json = """
        {
          "recorded_at": "2026-01-01T00:00:00Z",
          "app_name": "Safari",
          "window_title": "Google",
          "ide_project": null,
          "git_remote": null,
          "git_branch": null,
          "browser_url": "https://google.com",
          "is_idle": false,
          "idle_seconds": 0
        }
        """.data(using: .utf8)!
        let h = try JSONDecoder().decode(Heartbeat.self, from: json)
        XCTAssertEqual(h.appName, "Safari")
        XCTAssertEqual(h.browserUrl, "https://google.com")
    }
}
