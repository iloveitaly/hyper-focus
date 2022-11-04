import Foundation

class ScheduleManager {
  let configuration: Configuration

  var schedule: Configuration.ScheduleItem?
  var endOverride: Date?
  var endPause: Date?

  let BLANK_SCHEDULE = Configuration.ScheduleItem(
    block_hosts: [],
    block_urls: [],
    block_apps: []
  )

  init(configuration: Configuration) {
    self.configuration = configuration

    // setup timer to check if we need to change the schedule
    Timer.scheduledTimer(
      timeInterval: 60,
      target: self,
      selector: #selector(fireTimer),
      userInfo: nil,
      repeats: true
    )
  }

  @objc func fireTimer(timer _: Timer) {
    checkSchedule()
  }

  func pauseBlocking(_ end: Date) {
    log("pause blocking until \(end)")
    endPause = end
  }

  func namedSchedules() -> [Configuration.ScheduleItem] {
    return configuration.schedule.filter { $0.name != nil }
  }

  func scheduleOverride(name: String, end: Date) {
    log("schedule override \(name) until \(end)")

    // find a schedule with a name that matches the `name` parameter
    let schedule = namedSchedules().first { $0.name == name }

    if let schedule = schedule {
      endOverride = end
      setSchedule(schedule)
    } else {
      error("no schedule with name \(name)")
    }
  }

  func checkSchedule() {
    let now = Date()

    if endOverride != nil, now >= endOverride! {
      log("override date has passed, removing override")
      endOverride = nil
    }

    if endOverride != nil {
      log("currently in schedule override, skipping schedule check")
      return
    }

    let calendar = Calendar.current
    let hour = calendar.component(.hour, from: now)

    // select all schedules where the hour is greater than the start time
    let schedules = configuration.schedule.filter { $0.start != nil && $0.end != nil && hour >= $0.start! && hour <= $0.end! }

    if schedules.count > 1 {
      error("More than one schedule is active, this is not supported")
      return
    }

    // is the selected schedule different than the current one?
    if let schedule = schedules.first, schedule != self.schedule {
      log("changing schedule to \(schedule)")
      setSchedule(schedule)
    }
  }

  func setSchedule(_ schedule: Configuration.ScheduleItem) {
    // TODO: there's probably some race condition risk here, but I'm too lazy to understand swift concurrency locking
    self.schedule = schedule
  }

  func getSchedule() -> Configuration.ScheduleItem? {
    if endPause != nil, Date() < endPause! {
      return BLANK_SCHEDULE
    }

    return schedule
  }
}