import XCTest
@testable import hyper_focus

final class hyper_focusTests: XCTestCase {
    func testURLEquality() throws {
        XCTAssertEqual(true,
            ActionHandler.isSubsetOfUrl(
                supersetUrlString: "https://www.google.com/search?client=safari&rls=en&q=world+news&ie=UTF-8&oe=UTF-8",
                subsetUrlString: "https://www.google.com/search?q=world+news"
            )
        )
    }

    func testArrayURLEquality() throws {
        // the cocoa library for parsing query strings seems to fail on `[]` in query strings
        // on specific macos versions
        XCTAssertEqual(true, ActionHandler.isSubsetOfUrl(
            supersetUrlString: "http://monica.hole/people?tags[]=vc&other=var",
            subsetUrlString: "http://monica.hole/people?tags[]=vc"
        ))
    }
}
