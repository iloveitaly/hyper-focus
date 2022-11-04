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
    }

    lastWakeTime = currentDate

    log("awake from sleep")
  }
}