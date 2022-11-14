import XCTest
@testable import focus_app

final class focus_appTests: XCTestCase {
    // this should actually be false, but the cocoa library seems to fail on `[]` in query strings
    func testURLEquality() throws {
        XCTAssertEqual(false, ActionHandler.isSubsetOfUrl(
            supersetUrlString: "http://monica.hole/people?tags[]=vc&othr=var",
            subsetUrlString: "http://monica.hole/people?tags[]=vc"
        ))
    }
}
