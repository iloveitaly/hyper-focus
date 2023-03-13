import Cocoa
import Foundation

class SleepWatcher {
    let scheduleManager: ScheduleManager
    let configuration: Configuration
    let executionLocks: [String: Bool] = [:]

    var lastWakeTime: Date

    init(scheduleManager: ScheduleManager, configuration: Configuration) {
        self.scheduleManager = scheduleManager
        self.configuration = configuration

        // technically, not the last wake time, but we want to set an initial value on startup
        // to detect the next wake time tomorrow
        lastWakeTime = Date()

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(awakeFromSleep),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )

        log("sleepwatcher initialized")
    }

    @objc func awakeFromSleep(_ notification: Notification) {
        let currentDate = Date()
        let sameDayAsLastWake = Calendar.current.isDate(lastWakeTime, inSameDayAs: currentDate)

        // https://cs.github.com/rxhanson/Rectangle/blob/34753b6c9a75055cbc6b6e8d56bd0882760b5af7/Rectangle/ApplicationToggle.swift?q=NSWorkspace.shared.notificationCenter.addObserver+lang%3Aswift#L94
        debug("received wake notification at \(notification)")
        lastWakeTime = currentDate

        // is the last wake time non-nil and on a different day?
        // TODO: does this respect the local computer's timezone
        if !sameDayAsLastWake {
            debug("last wake was \(lastWakeTime) current time is \(currentDate)")
            log("first wake of the day")

            if let initialWake = configuration.initial_wake {
                executeTaskWithName(initialWake, "initial_wake")
            }
        }

        guard let wakeScript = configuration.wake else {
            log("no wake script configured")
            return
        }

        executeTaskWithName(wakeScript, "wake")
    }

    // TODO: can be used to run any script, we should add support for entry/exit scripts on a schedule
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

    func prefixLines(_ str: String, _ prefix: String) -> String {
        return str.split(separator: "\n").map { "[task-runner] [\(prefix)] \($0)" }.joined(separator: "\n")
    }
}
