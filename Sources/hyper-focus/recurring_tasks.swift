import Cocoa
import Cron

class RecurringTasksManager {
    let scheduleManager: ScheduleManager

    init(scheduleManager: ScheduleManager) {
        self.scheduleManager = scheduleManager
        start()
    }

    func start() {
        log("scheduling cron jobs")

        if let recurringTasks = scheduleManager.configuration.recurring_tasks {
            for task in recurringTasks {
                log("Scheduling task: \(task.task) with schedule: \(task.schedule)")
                let job = try? CronJob(pattern: task.schedule) { () in
                    log("executing task based on cron: \(task.task)")
                    TaskRunner.executeTaskWithName(task.task, task.task)
                }
            }
        }
    }
}
