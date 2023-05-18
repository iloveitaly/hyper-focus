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
        // the "anyInputEventType" is NOT defined in swift!
        // https://stackoverflow.com/questions/31943951/swift-and-my-idle-timer-implementation-missing-cgeventtype
        // https://developer.apple.com/documentation/coregraphics/cgeventsource/1408790-secondssincelasteventtype
        let anyInputEventType = CGEventType(rawValue: ~0)!

        let idleTimeInMilliseconds = CGEventSource.secondsSinceLastEventType(CGEventSourceStateID.combinedSessionState, eventType: anyInputEventType)
        return idleTimeInMilliseconds
    }

    private func checkActivity() {
        if wasEffectivelySleeping {
            return
        }

        let timeSinceLastActivity = systemIdleTime()

        // TODO: support sleeping in the same day

        let now = Date()
        let lastActivity = now.addingTimeInterval(-timeSinceLastActivity)
        let isInDifferentDay = !Calendar.current.isDate(lastActivity, inSameDayAs: now)

        if timeSinceLastActivity > intervalToConsiderSleeping, isInDifferentDay {
            log("is effectively sleeping, time since last activity \(timeSinceLastActivity), last activity \(lastActivity))")
            wasEffectivelySleeping = true
        }
    }

    func getAndClearWasEffectivelySleeping() -> Bool {
        let result = wasEffectivelySleeping
        wasEffectivelySleeping = false
        return result
    }
}
