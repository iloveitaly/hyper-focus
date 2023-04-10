import Foundation
import Quartz

class IdleChecker {
    private var wasEffectivelySleeping: Bool
    private var timer: Timer?

    init() {
        wasEffectivelySleeping = false
        startTimer()
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { [weak self] _ in
            self?.checkActivity()
        }
    }

    private func systemIdleTime() -> TimeInterval {
        let idleTimeInMilliseconds = CGEventSource.secondsSinceLastEventType(CGEventSourceStateID.hidSystemState, eventType: .null) * 1000
        return idleTimeInMilliseconds / 1000
    }

    private func checkActivity() {
        let idleTime = systemIdleTime()
        let now = Date()
        let lastActivity = now.addingTimeInterval(-idleTime)
        let timeSinceLastActivity = idleTime
        let calendar = Calendar.current
        let isInDifferentDay = !calendar.isDate(now, equalTo: lastActivity, toGranularity: .day)

        if timeSinceLastActivity > 5 * 3600, isInDifferentDay {
            debug("is effectively sleeping")
            wasEffectivelySleeping = true
        }
    }

    func getAndClearWasEffectivelySleeping() -> Bool {
        let result = wasEffectivelySleeping
        wasEffectivelySleeping = false
        return result
    }
}
