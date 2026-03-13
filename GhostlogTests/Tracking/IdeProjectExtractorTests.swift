import XCTest
@testable import Ghostlog

final class IdeProjectExtractorTests: XCTestCase {
    func testVSCode() {
        XCTAssertEqual(
            IdeProjectExtractor.extract(windowTitle: "index.ts — my-project — Visual Studio Code", appName: "Code"),
            "my-project"
        )
    }

    func testPhpStorm() {
        XCTAssertEqual(
            IdeProjectExtractor.extract(windowTitle: "homefans – src/app.ts – PhpStorm", appName: "PhpStorm"),
            "homefans"
        )
    }

    func testWebStorm() {
        XCTAssertEqual(
            IdeProjectExtractor.extract(windowTitle: "timetracking – index.ts – WebStorm", appName: "WebStorm"),
            "timetracking"
        )
    }

    func testFallbackKnownIde() {
        // OS stripped the IDE name from the title
        XCTAssertEqual(
            IdeProjectExtractor.extract(windowTitle: "my-project – some-file.ts", appName: "PhpStorm"),
            "my-project"
        )
    }

    func testNonIdeReturnsNil() {
        XCTAssertNil(IdeProjectExtractor.extract(windowTitle: "GitHub - my-project", appName: "Safari"))
        XCTAssertNil(IdeProjectExtractor.extract(windowTitle: "", appName: "Finder"))
    }
}
