import CryptoKit
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

    /// A stable digest of everything CalSync copies. Mappings only need to know whether the
    /// source changed, not the event text itself, so only this digest is persisted.
    var fingerprint: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = (try? encoder.encode(self)) ?? Data()
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
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
///
/// Only the destination identifier, the copied time range and a fingerprint are stored.
/// Older versions stored the full payload, which is read for migration and then dropped.
nonisolated struct MappingEntry: Codable, Hashable, Sendable {
    var destinationID: String
    var startDate: Date
    var endDate: Date
    var fingerprint: String
    /// Present only when decoding a mapping written by an older version.
    var legacyPayload: EventPayload?

    init(destinationID: String, payload: EventPayload) {
        self.destinationID = destinationID
        startDate = payload.startDate
        endDate = payload.endDate
        fingerprint = payload.fingerprint
        legacyPayload = nil
    }

    init(destinationID: String, startDate: Date, endDate: Date, fingerprint: String) {
        self.destinationID = destinationID
        self.startDate = startDate
        self.endDate = endDate
        self.fingerprint = fingerprint
        legacyPayload = nil
    }

    var needsMigration: Bool { legacyPayload != nil }
}

extension MappingEntry {
    private enum CodingKeys: String, CodingKey {
        case destinationID
        case startDate
        case endDate
        case fingerprint
        case payload
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        destinationID = try container.decode(String.self, forKey: .destinationID)

        let start = try container.decodeIfPresent(Date.self, forKey: .startDate)
        let end = try container.decodeIfPresent(Date.self, forKey: .endDate)
        let digest = try container.decodeIfPresent(String.self, forKey: .fingerprint)
        let oldPayload = try container.decodeIfPresent(EventPayload.self, forKey: .payload)

        if let start, let end, let digest {
            startDate = start
            endDate = end
            fingerprint = digest
            legacyPayload = oldPayload
        } else if let oldPayload {
            startDate = oldPayload.startDate
            endDate = oldPayload.endDate
            fingerprint = oldPayload.fingerprint
            legacyPayload = oldPayload
        } else {
            throw DecodingError.dataCorruptedError(
                forKey: .fingerprint,
                in: container,
                debugDescription: "Mapping entry has neither a fingerprint nor a legacy payload."
            )
        }
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(destinationID, forKey: .destinationID)
        try container.encode(startDate, forKey: .startDate)
        try container.encode(endDate, forKey: .endDate)
        try container.encode(fingerprint, forKey: .fingerprint)
    }
}
