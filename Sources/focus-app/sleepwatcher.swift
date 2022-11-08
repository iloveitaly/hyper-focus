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
        log("executing first wake script \(initialWake)")
        let task = Process()
        task.launchPath = NSString(string: initialWake).expandingTildeInPath
        task.launch()
      }
    }

    lastWakeTime = currentDate

    guard let wakeScript = configuration.wake else {
      log("no wake script configured")
      return
    }

    log("running wake script \(wakeScript)")

    let task = Process()
    task.launchPath = NSString(string: wakeScript).expandingTildeInPath
    task.launch()
  }
}