import Cocoa
import Foundation

struct TaskRunner {
    // TODO: don't allow more than one script type to execute at a time
    let executionLocks: [String: Bool] = [:]

    static func executeTaskWithName(_ rawCommandPath: String, _ taskName: String) {
        let expandedCommandPath = NSString(string: rawCommandPath).expandingTildeInPath

        if !FileManager.default.fileExists(atPath: expandedCommandPath) {
            error("script does not exist: \(expandedCommandPath)")
            return
        }

        let isCommandExecutable = FileManager.default.isExecutableFile(atPath: expandedCommandPath)

        log("running script \(expandedCommandPath)")

        let process = Process()
        let pipe = Pipe()
        let timeout = 120.0

        process.standardInput = FileHandle.nullDevice
        process.standardOutput = pipe
        process.standardError = pipe

        if isCommandExecutable {
            debug("command is executable, running directly")
            process.launchPath = expandedCommandPath
        } else {
            process.arguments = ["-c", expandedCommandPath]
            process.launchPath = "/bin/bash"
        }

        let timer: DispatchSourceTimer = DispatchSource.makeTimerSource(flags: [], queue: DispatchQueue.global())
        timer.schedule(deadline: .now() + timeout)
        timer.setEventHandler {
            error("\(timeout) second timeout reached, killing script \(expandedCommandPath)")
            process.terminate()
        }
        timer.resume()

        process.launch()
        process.waitUntilExit()
        timer.cancel()

        let status = process.terminationStatus

        if status != 0 {
            error("script \(expandedCommandPath) exited with error code \(status)")
        } else {
            log("script executed successfully")
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let resultString = String(data: data, encoding: .utf8)
        let prefixedString = prefixLines(resultString!, taskName)
        log("script output:\n\(prefixedString)")
    }

    static func prefixLines(_ str: String, _ prefix: String) -> String {
        return str.split(separator: "\n").map { "[task-runner] [\(prefix)] \($0)" }.joined(separator: "\n")
    }
}
