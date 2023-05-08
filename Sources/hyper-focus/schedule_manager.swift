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
        block_apps: [],
        allow_hosts: [],
        allow_urls: [],
        allow_apps: []
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
        let hour = calendar.component(.hour, from: now)
        let minute: Int = calendar.component(.minute, from: now)

        let schedules = configuration.schedule.filter {
            // exclude schedules which do not have a start & end time set (maybe only used for manual scheduling)
            $0.start != nil && $0.end != nil &&
                // select all schedules where the current hour is greater than the start time of the schedule
                hour >= $0.start! && hour <= $0.end! &&
                // support schedules optionally specifying the start and end minute as well
                ($0.start_minute == nil || hour != $0.start || minute >= $0.start_minute!) &&
                ($0.end_minute == nil || hour != $0.end || minute < $0.end_minute!)
        }

        if schedules.count > 1 {
            error("more than one schedule is active, this is not supported: \(schedules)")
            return
        }

        // is the selected schedule different than the current one?
        if let schedule = schedules.first {
            plannedSchedule = schedule
            setSchedule(schedule)
        } else {
            debug("no schedule is active, minute: \(minute), hour: \(hour)")

            // if no schedule is set, remove it
            plannedSchedule = nil
            setSchedule(nil)
        }
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

    func setSchedule(_ schedule: Configuration.ScheduleItem?) {
        if schedule == self.schedule {
            return
        }

        log("changing schedule to \(String(describing: schedule))")

        // TODO: there's probably some race condition risk here, but I'm too lazy to understand swift concurrency locking
        self.schedule = schedule

        if schedule != nil, schedule!.start_script != nil {
            TaskRunner.executeTaskWithName(schedule!.start_script!, "start_script")
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
