import Cocoa
import Foundation

class SleepWatcher {
    let scheduleManager: ScheduleManager
    let configuration: Configuration
    var lastWakeTime: Date?

    init(scheduleManager: ScheduleManager, configuration: Configuration) {
        self.scheduleManager = scheduleManager
        self.configuration = configuration

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(awakeFromSleep),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )

        log("sleepwatcher initialized")
    }

    @objc func awakeFromSleep() {
        let currentDate = Date()

        // is the last wake time non-nil and on a different day?
        if let lastWakeTime = lastWakeTime, !Calendar.current.isDate(lastWakeTime, inSameDayAs: currentDate) {
            log("first wake of the day")

            if let initialWake = configuration.initial_wake {
                // executeTask(initialWake)
                executeTaskWithName(initialWake, "initial_wake")
            }
        }

        lastWakeTime = currentDate

        guard let wakeScript = configuration.wake else {
            log("no wake script configured")
            return
        }

        // executeTask(wakeScript)
        executeTaskWithName(wakeScript, "wake")
    }

    func executeTask(_ taskPath: String) {
        let expandedScript = NSString(string: taskPath).expandingTildeInPath

        if !FileManager.default.fileExists(atPath: expandedScript) {
            error("script does not exist: \(expandedScript)")
            return
        }

        log("running script \(expandedScript)")

        // TODO: need some sort of timeout and not wait for input
        //      https://developer.apple.com/documentation/dispatch/dispatchgroup/1780590-wait

        let task = Process()
        task.standardInput = FileHandle.nullDevice
        task.launchPath = expandedScript

        do {
            try task.run()
        } catch {
            log("failed to run script \(expandedScript) \(error)")
            return
        }

        task.waitUntilExit()

        let status = task.terminationStatus

        if status != 0 {
            error("script \(expandedScript) exited with error code \(status)")
            return
        }

        log("script executed successfully")
    }

    func executeTaskWithName(_ rawCommandPath: String, _ taskName: String) {
        let expandedCommandPath = NSString(string: rawCommandPath).expandingTildeInPath

        if !FileManager.default.fileExists(atPath: expandedCommandPath) {
            error("script does not exist: \(expandedCommandPath)")
            return
        }

        // is expandedCommandPath executable?
        let isCommandExecutable = FileManager.default.isExecutableFile(atPath: expandedCommandPath)

        log("running script \(expandedCommandPath)")

        let process = Process()
        let pipe = Pipe()
        let timeout = 120.0

        // no user input
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

        let timer = DispatchSource.makeTimerSource(flags: [], queue: DispatchQueue.global())
        timer.schedule(deadline: .now() + timeout)
        timer.setEventHandler {
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

    func prefixLines(_ str: String, _ prefix: String) -> String {
        return str.split(separator: "\n").map { "[task-runner] [\(prefix)] \($0)" }.joined(separator: "\n")
    }
}
