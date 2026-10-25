import Foundation

/// The fields CalSync writes to a destination event. Equality decides whether a copy needs updating.
nonisolated struct EventPayload: Codable, Hashable, Sendable {
    var title: String
    var startDate: Date
    var endDate: Date
    var isAllDay: Bool
    var timeZoneID: String?
    var location: String?
    var notes: String?
    var url: URL?
    var alarmOffsets: [TimeInterval] = []

    func overlaps(_ window: DateInterval) -> Bool {
        startDate < window.end && endDate > window.start
    }
}

/// A single occurrence of a source event. `key` is stable across syncs for the same occurrence.
nonisolated struct SourceOccurrence: Hashable, Sendable {
    var key: String
    var payload: EventPayload
}

nonisolated struct DestinationEvent: Hashable, Sendable {
    var id: String
    var payload: EventPayload
}

/// Links a source occurrence to the copy CalSync created for it.
nonisolated struct MappingEntry: Codable, Hashable, Sendable {
    var destinationID: String
    var payload: EventPayload
}
