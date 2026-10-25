import Foundation

nonisolated enum SyncAction: Hashable, Sendable {
    case create(SourceOccurrence)
    case update(destinationID: String, SourceOccurrence)
    case delete(destinationID: String, key: String)
}

nonisolated struct SyncPlan: Hashable, Sendable {
    var actions: [SyncAction] = []
    /// Mapping keys to drop without touching the destination calendar.
    var forget: [String] = []
    var unchanged = 0
}

/// Decides what to do for one sync run. Pure and EventKit-free so it can be unit tested.
nonisolated enum SyncPlanner {
    private struct MatchKey: Hashable {
        var title: String
        var start: Date
        var end: Date
        var isAllDay: Bool

        init(_ payload: EventPayload) {
            title = payload.title
            start = payload.startDate
            end = payload.endDate
            isAllDay = payload.isAllDay
        }
    }

    /// - Parameters:
    ///   - source: Occurrences currently in the source calendar within `window`.
    ///   - mapping: Copies made by earlier runs, keyed by occurrence key.
    ///   - existingDestinationIDs: Mapped destination IDs that still exist in the destination calendar.
    ///   - destinationEvents: Events currently in the destination calendar within `window`; used to
    ///     re-link identical events instead of creating duplicates (e.g. after a reinstall).
    static func plan(
        source: [SourceOccurrence],
        mapping: [String: MappingEntry],
        existingDestinationIDs: Set<String>,
        destinationEvents: [DestinationEvent],
        window: DateInterval,
        deleteRemoved: Bool
    ) -> SyncPlan {
        var plan = SyncPlan()

        let claimed = Set(mapping.values.map(\.destinationID)).intersection(existingDestinationIDs)
        var adoptable: [MatchKey: [String]] = [:]
        for event in destinationEvents where !claimed.contains(event.id) {
            adoptable[MatchKey(event.payload), default: []].append(event.id)
        }

        var seen = Set<String>()
        for occurrence in source {
            guard seen.insert(occurrence.key).inserted else { continue }

            if let entry = mapping[occurrence.key], existingDestinationIDs.contains(entry.destinationID) {
                if entry.payload == occurrence.payload {
                    plan.unchanged += 1
                } else {
                    plan.actions.append(.update(destinationID: entry.destinationID, occurrence))
                }
            } else if let id = adoptable[MatchKey(occurrence.payload)]?.popLast() {
                plan.actions.append(.update(destinationID: id, occurrence))
            } else {
                plan.actions.append(.create(occurrence))
            }
        }

        for (key, entry) in mapping.sorted(by: { $0.key < $1.key }) where !seen.contains(key) {
            if entry.payload.endDate <= window.start {
                // Scrolled out of the past edge of the window: keep the copy, stop tracking it.
                plan.forget.append(key)
            } else if !entry.payload.overlaps(window) {
                // Beyond the window (e.g. the range was shortened): keep tracking for later runs.
                continue
            } else if deleteRemoved && existingDestinationIDs.contains(entry.destinationID) {
                plan.actions.append(.delete(destinationID: entry.destinationID, key: key))
            } else {
                plan.forget.append(key)
            }
        }

        return plan
    }
}
