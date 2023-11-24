@testable import hyper_focus
import XCTest

final class task_runnerTests: XCTestCase {
    func testFailedNonExecutableScriptRun() throws {
        let tempFile = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test.sh")
        try! "sleep 30; echo 'execution error: Flow got an error: AppleEvent timed out.' >&2; exit 1".write(to: tempFile, atomically: true, encoding: .utf8)

        TaskRunner.executeTaskWithName(tempFile.path, "script_start")

        // try running again
        TaskRunner.executeTaskWithName(tempFile.path, "script_start")

        do {
            try FileManager.default.removeItem(at: tempFile)
        } catch {
            XCTFail("Error cleaning up temporary file: \(error)")
        }
    }

    func testParallelNonExecutableScriptRun() throws {
        let tempFile = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test.sh")
        try! "sleep 30; echo 'execution error: Flow got an error: AppleEvent timed out.' >&2; exit 1".write(to: tempFile, atomically: true, encoding: .utf8)

        let expectation1 = expectation(description: "First script completion")
        let expectation2 = expectation(description: "Second script completion")

        DispatchQueue.global().async {
            TaskRunner.executeTaskWithName(tempFile.path, "script_start")
            expectation1.fulfill()
        }

        DispatchQueue.global().async {
            TaskRunner.executeTaskWithName(tempFile.path, "script_start")
            expectation2.fulfill()
        }

        wait(for: [expectation1, expectation2], timeout: 35.0)

        do {
            try FileManager.default.removeItem(at: tempFile)
        } catch {
            XCTFail("Error cleaning up temporary file: \(error)")
        }
    }
}
