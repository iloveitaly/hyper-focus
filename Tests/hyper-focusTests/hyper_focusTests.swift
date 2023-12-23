@testable import hyper_focus
import XCTest

final class hyper_focusTests: XCTestCase {
    func testURLEquality() throws {
        XCTAssertEqual(true,
                       ActionHandler.isSubsetOfUrl(
                           supersetUrlString: "https://www.google.com/search?client=safari&rls=en&q=world+news&ie=UTF-8&oe=UTF-8",
                           subsetUrlString: "https://www.google.com/search?q=world+news"
                       ))
    }

    func testArrayURLEquality() throws {
        // I'm not sure *exactly* why this test is failing, but what I do know is it's failing on GH CI which does not yet
        // support ventura. Remove this once a new runner is released. https://github.com/actions/runner-images/issues/6426
        if !ProcessInfo().isOperatingSystemAtLeast(OperatingSystemVersion(majorVersion: 15, minorVersion: 0, patchVersion: 0)) {
            print("not ventura, this test fails under ventura")
            return
        }
        // the cocoa library for parsing query strings seems to fail on `[]` in query strings
        // on specific macos versions
        XCTAssertEqual(true, ActionHandler.isSubsetOfUrl(
            supersetUrlString: "http://monica.hole/people?tags[]=vc&other=var",
            subsetUrlString: "http://monica.hole/people?tags[]=vc"
        ))
    }

    func testURLWithoutQueryStringEquality() throws {
        let exampleUrl = "https://github.com/iloveitaly"
        XCTAssertEqual(true,
                       ActionHandler.isSubsetOfUrl(supersetUrlString: exampleUrl, subsetUrlString: exampleUrl))
    }

    func testInitialWakeNotification() throws {
        let previousDayTimestamp: TimeInterval = 1_677_355_905
        let nextDayTimestamp: TimeInterval = 1_677_441_607

        let configuration = mockConfiguration()
        let scheduleManager = ScheduleManager(configuration)
        let sleepWatcher = SleepWatcher(scheduleManager: scheduleManager, dateGenerator: { Date(timeIntervalSince1970: nextDayTimestamp) })

        // TODO: we should assert that the wake script is actually run in this case, but this will require some refactoring
        sleepWatcher.lastWakeTime = Date(timeIntervalSince1970: previousDayTimestamp)
        sleepWatcher.awakeFromSleep(mockWakeNotification())
    }

    // TODO: mmm these dates don't look right
    func testInitialWakeNotificationWhichShouldNotFire() throws {
        // 2023-04-18 18:03:37 +0000
        // April 18, 2023 at 12:03:37 PM Mountain Daylight Time
        let previousDayInUTCTimestamp = 1_681_841_017
        // 2023-04-19 23:39:08 +0000
        // April 19, 2023 at 5:39:08 PM Mountain Daylight Time
        let currentDayTimestamp = 1_681_947_548
    }

    func mockWakeNotification() -> Notification {
        let mockNotification = Notification(name: NSWorkspace.didWakeNotification, object: nil, userInfo: nil)
        return mockNotification
    }

    func mockConfiguration() -> Configuration {
        let testScheduleItem = Configuration.ScheduleItem(
            start: 8 * 60,
            end: 18 * 60,
            name: "Work Hours",
            start_script: "/path/to/start_script.sh",
            block_hosts: ["example.com"],
            block_urls: ["example.org"],
            block_apps: ["AppName"]
        )

        let testConfiguration = Configuration(
            initial_wake: "/path/to/initial_wake.sh",
            wake: "/path/to/wake.sh",
            schedule: [testScheduleItem]
        )

        return testConfiguration
    }
}
