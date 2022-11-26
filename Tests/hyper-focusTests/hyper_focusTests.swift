import XCTest
@testable import hyper_focus

final class hyper_focusTests: XCTestCase {
    // this should actually be false, but the cocoa library seems to fail on `[]` in query strings
    func testURLEquality() throws {
        XCTAssertEqual(true, ActionHandler.isSubsetOfUrl(
            supersetUrlString: "http://monica.hole/people?tags[]=vc&other=var",
            subsetUrlString: "http://monica.hole/people?tags[]=vc"
        ))
    }
}
