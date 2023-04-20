import Cocoa
import Foundation

typealias DateGenerator = () -> Date

class SleepWatcher {
    let scheduleManager: ScheduleManager
    let dateGenerator: DateGenerator
    let idleChecker: IdleChecker

    var lastWakeTime: Date

    init(scheduleManager: ScheduleManager, dateGenerator: @escaping DateGenerator = { Date() }) {
        idleChecker = IdleChecker()

        self.scheduleManager = scheduleManager

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

        // https://cs.github.com/glushchenko/fsnotes/blob/a1c0d9a2b955dffa63c1841cdccc72df0ea24f78/FSNotes/ViewController.swift?q=NSWorkspace.sessionDidBecomeActiveNotification+lang%3Aswift#L507
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(userDidUnlockScreen(note:)),
            // unsure why this doesn't use the standard notification center
            name: Notification.Name("com.apple.screenIsUnlocked"),
            object: nil
        )

        log("sleepwatcher initialized")
    }

    // if the computer is left on without sleeping, we want to treat a login as if if the computer was sleeping
    @objc func userDidUnlockScreen(note _: Notification) {
        debug("user logged in")

        let isFirstWakeInAwhile = idleChecker.getAndClearWasEffectivelySleeping()

        if isFirstWakeInAwhile {
            log("computer was effectively sleeping, triggering wake scripts")
            lastWakeTime = dateGenerator()
            runInitialWakeScript()
            runWakeScript()
        }
    }

    // https://cs.github.com/rxhanson/Rectangle/blob/34753b6c9a75055cbc6b6e8d56bd0882760b5af7/Rectangle/ApplicationToggle.swift?q=NSWorkspace.shared.notificationCenter.addObserver+lang%3Aswift#L94
    @objc func awakeFromSleep(_: Notification) {
        debug("received wake notification, last wake was \(lastWakeTime) current time is \(dateGenerator())")

        idleChecker.wasEffectivelySleeping = false

        let isFirstWakeOfTheDay = firstWakeOfTheDay()
        lastWakeTime = dateGenerator()

        // is the last wake time non-nil and on a different day?
        if isFirstWakeOfTheDay {
            log("first wake of the day")
            runInitialWakeScript()
        }

        runWakeScript()
    }

    private func firstWakeOfTheDay() -> Bool {
        let currentDate = dateGenerator()
        let sameDayAsLastWake = Calendar.current.isDate(lastWakeTime, inSameDayAs: currentDate)
        return !sameDayAsLastWake
    }

    private func runInitialWakeScript() {
        guard let initialWake = scheduleManager.configuration.initial_wake else {
            log("no initial wake script configured")
            return
        }

        TaskRunner.executeTaskWithName(initialWake, "initial_wake")
    }

    private func runWakeScript() {
        guard let wakeScript = scheduleManager.configuration.wake else {
            log("no wake script configured")
            return
        }

        TaskRunner.executeTaskWithName(wakeScript, "wake")
    }
}
