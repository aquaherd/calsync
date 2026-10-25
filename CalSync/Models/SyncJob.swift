import Foundation

/// A configured one-way copy from a source calendar to a destination calendar.
nonisolated struct SyncJob: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var sourceCalendarID = ""
    var destinationCalendarID = ""
    /// Names and account identifiers let a job survive an account being removed and added again,
    /// which gives its calendars new identifiers.
    var sourceCalendarTitle: String?
    var destinationCalendarTitle: String?
    var sourceAccountID: String?
    var destinationAccountID: String?
    var sourceAccountTitle: String?
    var destinationAccountTitle: String?
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

extension SyncJob {
    private enum CodingKeys: String, CodingKey {
        case id
        case sourceCalendarID
        case destinationCalendarID
        case sourceCalendarTitle
        case destinationCalendarTitle
        case sourceAccountID
        case destinationAccountID
        case sourceAccountTitle
        case destinationAccountTitle
        case daysBack
        case daysAhead
        case options
        case isEnabled
        case lastResult
    }

    /// Decodes with defaults so that a field added in a later version does not make
    /// the existing `jobs.json` unreadable.
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        sourceCalendarID = try container.decodeIfPresent(String.self, forKey: .sourceCalendarID) ?? ""
        destinationCalendarID = try container.decodeIfPresent(String.self, forKey: .destinationCalendarID) ?? ""
        sourceCalendarTitle = try container.decodeIfPresent(String.self, forKey: .sourceCalendarTitle)
        destinationCalendarTitle = try container.decodeIfPresent(String.self, forKey: .destinationCalendarTitle)
        sourceAccountID = try container.decodeIfPresent(String.self, forKey: .sourceAccountID)
        destinationAccountID = try container.decodeIfPresent(String.self, forKey: .destinationAccountID)
        sourceAccountTitle = try container.decodeIfPresent(String.self, forKey: .sourceAccountTitle)
        destinationAccountTitle = try container.decodeIfPresent(String.self, forKey: .destinationAccountTitle)
        daysBack = try container.decodeIfPresent(Int.self, forKey: .daysBack) ?? 7
        daysAhead = try container.decodeIfPresent(Int.self, forKey: .daysAhead) ?? 60
        options = try container.decodeIfPresent(SyncOptions.self, forKey: .options) ?? SyncOptions()
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        lastResult = try container.decodeIfPresent(SyncResult.self, forKey: .lastResult)
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
    var privateTitle = String(localized: "Busy")
    /// Delete copies whose source event no longer exists.
    var deleteRemoved = true
}

extension SyncOptions {
    private enum CodingKeys: String, CodingKey {
        case copyNotes
        case copyLocation
        case copyURL
        case copyAlarms
        case skipAllDay
        case skipDeclined
        case privateMode
        case privateTitle
        case deleteRemoved
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        copyNotes = try container.decodeIfPresent(Bool.self, forKey: .copyNotes) ?? true
        copyLocation = try container.decodeIfPresent(Bool.self, forKey: .copyLocation) ?? true
        copyURL = try container.decodeIfPresent(Bool.self, forKey: .copyURL) ?? true
        copyAlarms = try container.decodeIfPresent(Bool.self, forKey: .copyAlarms) ?? false
        skipAllDay = try container.decodeIfPresent(Bool.self, forKey: .skipAllDay) ?? false
        skipDeclined = try container.decodeIfPresent(Bool.self, forKey: .skipDeclined) ?? true
        privateMode = try container.decodeIfPresent(Bool.self, forKey: .privateMode) ?? false
        privateTitle = try container.decodeIfPresent(String.self, forKey: .privateTitle) ?? String(localized: "Busy")
        deleteRemoved = try container.decodeIfPresent(Bool.self, forKey: .deleteRemoved) ?? true
    }
}

nonisolated struct SyncResult: Codable, Hashable, Sendable {
    var date = Date.now
    var created = 0
    var updated = 0
    var deleted = 0
    var unchanged = 0
    var failed = 0
    var error: String?
    /// Up to a handful of per-event failures, so "3 failed" is not the only information.
    var failures: [String] = []
    /// Set when the run stopped before deleting a suspiciously large number of copies.
    var blockedDeletions = 0

    var summary: String {
        if let error { return error }
        let plural = { (key: String, count: Int) in
            String.localizedStringWithFormat(NSLocalizedString(key, comment: ""), count)
        }
        var parts: [String] = []
        if created > 0 { parts.append(plural("%lld added", created)) }
        if updated > 0 { parts.append(plural("%lld updated", updated)) }
        if deleted > 0 { parts.append(plural("%lld removed", deleted)) }
        if failed > 0 { parts.append(plural("%lld failed", failed)) }
        return parts.isEmpty ? plural("Up to date (%lld events)", unchanged) : parts.joined(separator: ", ")
    }
}

extension SyncResult {
    private enum CodingKeys: String, CodingKey {
        case date
        case created
        case updated
        case deleted
        case unchanged
        case failed
        case error
        case failures
        case blockedDeletions
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        date = try container.decodeIfPresent(Date.self, forKey: .date) ?? .now
        created = try container.decodeIfPresent(Int.self, forKey: .created) ?? 0
        updated = try container.decodeIfPresent(Int.self, forKey: .updated) ?? 0
        deleted = try container.decodeIfPresent(Int.self, forKey: .deleted) ?? 0
        unchanged = try container.decodeIfPresent(Int.self, forKey: .unchanged) ?? 0
        failed = try container.decodeIfPresent(Int.self, forKey: .failed) ?? 0
        error = try container.decodeIfPresent(String.self, forKey: .error)
        failures = try container.decodeIfPresent([String].self, forKey: .failures) ?? []
        blockedDeletions = try container.decodeIfPresent(Int.self, forKey: .blockedDeletions) ?? 0
    }
}
