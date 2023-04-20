import Foundation

class ScheduleManager {
    var configuration: Configuration

    var schedule: Configuration.ScheduleItem?
    var endOverride: Date?
    var endPause: Date?

    // only used for API, not used in the implementation
    var overrideSchedule: Configuration.ScheduleItem?
    var plannedSchedule: Configuration.ScheduleItem?

    let BLANK_SCHEDULE = Configuration.ScheduleItem(
        block_hosts: [],
        block_urls: [],
        block_apps: []
    )

    init(_ config: Configuration? = nil) {
        configuration = config ?? ConfigurationLoader.loadConfiguration()

        // setup timer to check if we need to change the schedule
        Timer.scheduledTimer(
            timeInterval: 60,
            target: self,
            selector: #selector(fireTimer),
            userInfo: nil,
            repeats: true
        )

        checkSchedule()
    }

    func reloadConfiguration() {
        configuration = ConfigurationLoader.loadConfiguration()
        checkSchedule()
    }

    @objc func fireTimer(timer _: Timer) {
        checkSchedule()
    }

    func pauseBlocking(_ end: Date) {
        log("pause blocking until \(end)")
        endPause = end
    }

    func schedules() -> [Configuration.ScheduleItem] {
        return configuration.schedule
    }

    func scheduleOverride(name: String, end: Date) {
        log("schedule override \(name) until \(end)")

        // find a schedule with a name that matches the `name` parameter
        let schedule = schedules().first { $0.name != nil && $0.name == name }

        if let schedule = schedule {
            endOverride = end
            overrideSchedule = schedule
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
            overrideSchedule = nil
        }

        if endOverride != nil {
            log("currently in schedule override, skipping schedule check")
            return
        }

        let calendar = Calendar.current
        // TODO(GPT) this may need to be adjusted to support minute specification
        let hour = calendar.component(.hour, from: now)

        // TODO(GPT) support schedules optionally specifying the start and end minute as well
        // select all schedules where the hour is greater than the start time
        let schedules = configuration.schedule.filter {
            $0.start != nil && $0.end != nil &&
                hour >= $0.start! && hour <= $0.end!
        }

        if schedules.count > 1 {
            error("More than one schedule is active, this is not supported")
            return
        }

        // is the selected schedule different than the current one?
        if let schedule = schedules.first {
            plannedSchedule = schedule
            setSchedule(schedule)
        } else {
            plannedSchedule = nil
            setSchedule(nil)
        }
    }

    func setSchedule(_ schedule: Configuration.ScheduleItem?) {
        if schedule != self.schedule {
            log("changing schedule to \(String(describing: schedule))")
            // TODO: there's probably some race condition risk here, but I'm too lazy to understand swift concurrency locking
            self.schedule = schedule

            if schedule != nil, schedule!.start_script != nil {
                TaskRunner.executeTaskWithName(schedule!.start_script!, "start_script")
            }
        }
    }

    func getSchedule() -> Configuration.ScheduleItem? {
        // TODO: weird to have this check vs in the check poller, but we need a conditional to return BLANK_SCHEDULE
        if endPause != nil, Date() < endPause! {
            return BLANK_SCHEDULE
        } else {
            endPause = nil
        }

        return schedule
    }
}
