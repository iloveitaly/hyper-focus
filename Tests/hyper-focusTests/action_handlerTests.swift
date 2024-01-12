@testable import hyper_focus
import XCTest

final class action_handlerTests: XCTestCase {
    func testMatches() throws {
        XCTAssertEqual(false, ActionHandler.match("something", []))
        XCTAssertEqual(true, ActionHandler.match("google.com", ["google.com"]))

        // make sure . is not interpreted as a regex
        XCTAssertEqual(false, ActionHandler.match("googleXcom", ["google.com"]))

        XCTAssertEqual(true, ActionHandler.match("google.com", ["/google.*/"]))
        XCTAssertEqual(true, ActionHandler.match("admin.google.com", ["/google.*/"]))

        XCTAssertEqual(true, ActionHandler.match("google.com/news", ["/google.*/"]))

        XCTAssertEqual(true, ActionHandler.match("google.com/news/something", ["/^google.*/", "google.com/news"]))
    }

    // TODO: test full stack browserAction
}
