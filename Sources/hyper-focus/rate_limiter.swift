import Foundation

class RateLimiter {
    private var timestamps: [String: [Date]] = [:]

    // actions per hour
    var limit: Int?

    func allowed(type: String) -> Bool {
        if limit == nil {
            debug("no limit set, allowing action '\(type)'")
            return true
        }

        let now = Date()
        let oneHourAgo = now.addingTimeInterval(-3600)

        var typeStamps = timestamps[type, default: []]
        typeStamps = typeStamps.filter { $0 > oneHourAgo }

        if typeStamps.count < limit! {
            typeStamps.append(now)
            timestamps[type] = typeStamps
            return true
        }

        // Update the timestamps to remove stale entries
        timestamps[type] = typeStamps
        return false
    }
}
