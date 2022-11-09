import Foundation
import Cocoa

class SleepWatcher {
  let scheduleManager: ScheduleManager
  let configuration: Configuration
  var lastWakeTime: Date?

  init(scheduleManager: ScheduleManager, configuration: Configuration) {
    self.scheduleManager = scheduleManager
    self.configuration = configuration

    NSWorkspace.shared.notificationCenter.addObserver(
      self,
      selector: #selector(self.awakeFromSleep),
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
        executeTask(initialWake)
      }
    }

    lastWakeTime = currentDate

    guard let wakeScript = configuration.wake else {
      log("no wake script configured")
      return
    }

    executeTask(wakeScript)
  }

  func executeTask(_ taskPath: String) {
    let expandedScript = NSString(string: taskPath).expandingTildeInPath

    log("running script \(expandedScript)")

    // TODO need some sort of timeout and not wait for input

    let task = Process()
    task.standardInput = FileHandle.nullDevice
    task.launchPath = expandedScript
    task.run()
    task.waitUntilExit()

    let status = task.terminationStatus
    if status != 0 {
      error("script \(expandedScript) exited with error code \(status)")
    }
  }
}