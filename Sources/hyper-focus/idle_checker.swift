import Foundation
import Quartz

class IdleChecker {
    private let idleCheckInterval: TimeInterval = 60 * 10
    private let intervalToConsiderSleeping: TimeInterval = 5 * 60 * 60

    var wasEffectivelySleeping: Bool

    // TODO: bad variable name!
    private var timer: Timer?

    init() {
        log("idle checker initialized")
        wasEffectivelySleeping = false
        startTimer()
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: idleCheckInterval, repeats: true) { [weak self] _ in
            self?.checkActivity()
        }
    }

    private func systemIdleTime() -> TimeInterval {
        let idleTimeInMilliseconds = CGEventSource.secondsSinceLastEventType(CGEventSourceStateID.hidSystemState, eventType: .null) * 1000
        return idleTimeInMilliseconds / 1000
    }

    private func checkActivity() {
        if wasEffectivelySleeping {
            return
        }

        let timeSinceLastActivity = systemIdleTime()

        let now = Date()
        let lastActivity = now.addingTimeInterval(-timeSinceLastActivity)
        let isInDifferentDay = !Calendar.current.isDate(lastActivity, inSameDayAs: now)

        if timeSinceLastActivity > intervalToConsiderSleeping, isInDifferentDay {
            log("is effectively sleeping")
            wasEffectivelySleeping = true
        }
    }

    func getAndClearWasEffectivelySleeping() -> Bool {
        let result = wasEffectivelySleeping
        wasEffectivelySleeping = false
        return result
    }
}
