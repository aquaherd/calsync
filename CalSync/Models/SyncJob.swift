import Foundation

/// A configured one-way copy from a source calendar to a destination calendar.
nonisolated struct SyncJob: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var sourceCalendarID = ""
    var destinationCalendarID = ""
    var daysBack = 7
    var daysAhead = 60
    var options = SyncOptions()
    var isEnabled = true
    var lastResult: SyncResult?

    var isValid: Bool {
        !sourceCalendarID.isEmpty && !destinationCalendarID.isEmpty && sourceCalendarID != destinationCalendarID
    }

    func window(now: Date = .now, calendar: Calendar = .current) -> DateInterval {
        let today = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -daysBack, to: today) ?? today
        let end = calendar.date(byAdding: .day, value: daysAhead + 1, to: today) ?? today
        return DateInterval(start: start, end: end)
    }
}

nonisolated struct SyncOptions: Codable, Hashable, Sendable {
    var copyNotes = true
    var copyLocation = true
    var copyURL = true
    var copyAlarms = false
    var skipAllDay = false
    var skipDeclined = true
    /// Replace titles with `privateTitle` and drop all other details.
    var privateMode = false
    var privateTitle = "Busy"
    /// Delete copies whose source event no longer exists.
    var deleteRemoved = true
}

nonisolated struct SyncResult: Codable, Hashable, Sendable {
    var date = Date.now
    var created = 0
    var updated = 0
    var deleted = 0
    var unchanged = 0
    var failed = 0
    var error: String?

    var summary: String {
        if let error { return error }
        var parts: [String] = []
        if created > 0 { parts.append("\(created) added") }
        if updated > 0 { parts.append("\(updated) updated") }
        if deleted > 0 { parts.append("\(deleted) removed") }
        if failed > 0 { parts.append("\(failed) failed") }
        return parts.isEmpty ? "Up to date (\(unchanged) events)" : parts.joined(separator: ", ")
    }
}
