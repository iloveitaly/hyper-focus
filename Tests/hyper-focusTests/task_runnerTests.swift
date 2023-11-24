@testable import hyper_focus
import XCTest

final class task_runnerTests: XCTestCase {
    func testFailedNonExecutableScriptRun() throws {
        let tempFile = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test.sh")
        try! "sleep 30; echo 'execution error: Flow got an error: AppleEvent timed out.' >&2; exit 1".write(to: tempFile, atomically: true, encoding: .utf8)

        TaskRunner.executeTaskWithName(tempFile.path, "script_start")

        // try running again
        TaskRunner.executeTaskWithName(tempFile.path, "script_start")

        // defer is like finally in other languages
        defer {
            try! FileManager.default.removeItem(at: tempFile)
        }
    }
}
