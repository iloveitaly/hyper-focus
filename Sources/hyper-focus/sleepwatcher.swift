import Cocoa
import Foundation

typealias DateGenerator = () -> Date

class SleepWatcher {
    let scheduleManager: ScheduleManager
    let configuration: Configuration
    let dateGenerator: DateGenerator

    var lastWakeTime: Date

    init(scheduleManager: ScheduleManager, configuration: Configuration, dateGenerator: @escaping DateGenerator = { Date() }) {
        self.scheduleManager = scheduleManager
        self.configuration = configuration

        // allows us to time travel within tests
        self.dateGenerator = dateGenerator

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

    @objc func awakeFromSleep(_: Notification) {
        let currentDate = dateGenerator()
        let sameDayAsLastWake = Calendar.current.isDate(lastWakeTime, inSameDayAs: currentDate)

        // https://cs.github.com/rxhanson/Rectangle/blob/34753b6c9a75055cbc6b6e8d56bd0882760b5af7/Rectangle/ApplicationToggle.swift?q=NSWorkspace.shared.notificationCenter.addObserver+lang%3Aswift#L94
        debug("received wake notification, last wake was \(lastWakeTime) current time is \(currentDate)")
        lastWakeTime = currentDate

        // is the last wake time non-nil and on a different day?
        // TODO: does this respect the local computer's timezone
        if !sameDayAsLastWake {
            log("first wake of the day")

            if let initialWake = configuration.initial_wake {
                TaskRunner.executeTaskWithName(initialWake, "initial_wake")
            }
        }

        guard let wakeScript = configuration.wake else {
            log("no wake script configured")
            return
        }

        TaskRunner.executeTaskWithName(wakeScript, "wake")
    }
}
