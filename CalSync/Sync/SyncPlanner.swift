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

    var deletionCount: Int {
        actions.reduce(0) { count, action in
            if case .delete = action { return count + 1 }
            return count
        }
    }
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
    ///   - source: Occurrences currently in the source calendars within `window`. A merge job
    ///     gives occurrences of the same meeting the same key.
    ///   - mapping: Copies made by earlier runs, keyed by occurrence key.
    ///   - existingDestinationIDs: Mapped destination IDs that still exist in the destination calendar.
    ///   - claimedDestinationIDs: Destination IDs that belong to another job. They are never
    ///     adopted, so two jobs cannot take over and fight over the same copy.
    ///   - destinationEvents: Events currently in the destination calendar within `window`; used to
    ///     re-link identical events instead of creating duplicates (e.g. after a reinstall).
    static func plan(
        source: [SourceOccurrence],
        mapping: [String: MappingEntry],
        existingDestinationIDs: Set<String>,
        claimedDestinationIDs: Set<String> = [],
        destinationEvents: [DestinationEvent],
        window: DateInterval,
        deleteRemoved: Bool,
        mergeDuplicates: Bool = false
    ) -> SyncPlan {
        var plan = SyncPlan()

        // A mapping only reserves its destination while its key is still in the source. A key
        // can change, for example when a job gains a second source and starts using meeting
        // identities. Such an old copy must be adoptable, not left to be deleted after a twin
        // was created.
        let sourceKeys = Set(source.map(\.key))
        let reserved = Set(mapping.compactMap { pair -> String? in
            sourceKeys.contains(pair.key) ? pair.value.destinationID : nil
        })

        var adoptable: [MatchKey: [DestinationEvent]] = [:]
        var adoptableByMeeting: [String: [DestinationEvent]] = [:]
        for event in destinationEvents
        where !reserved.contains(event.id) && !claimedDestinationIDs.contains(event.id) {
            adoptable[MatchKey(event.payload), default: []].append(event)
            if mergeDuplicates {
                let identity = MeetingIdentity.of(event.payload)
                if identity.isStrong {
                    adoptableByMeeting[identity.key, default: []].append(event)
                }
            }
        }

        var usedDestinationIDs = Set<String>()
        var seen = Set<String>()
        for occurrence in source {
            guard seen.insert(occurrence.key).inserted else { continue }

            if let entry = mapping[occurrence.key], existingDestinationIDs.contains(entry.destinationID) {
                usedDestinationIDs.insert(entry.destinationID)
                if entry.fingerprint == occurrence.payload.fingerprint {
                    plan.unchanged += 1
                } else {
                    plan.actions.append(.update(destinationID: entry.destinationID, occurrence))
                }
            } else if mergeDuplicates, occurrence.hasStrongIdentity,
                      let matched = takeAdoptable(
                        meeting: occurrence.key,
                        from: &adoptableByMeeting,
                        excluding: usedDestinationIDs
                      ) {
                usedDestinationIDs.insert(matched.id)
                plan.actions.append(.update(destinationID: matched.id, occurrence))
            } else if let matched = takeAdoptable(
                matching: occurrence.payload,
                from: &adoptable,
                excluding: usedDestinationIDs
            ) {
                usedDestinationIDs.insert(matched.id)
                plan.actions.append(.update(destinationID: matched.id, occurrence))
            } else {
                plan.actions.append(.create(occurrence))
            }
        }

        for (key, entry) in mapping.sorted(by: { $0.key < $1.key }) where !seen.contains(key) {
            if usedDestinationIDs.contains(entry.destinationID)
                || claimedDestinationIDs.contains(entry.destinationID) {
                // The copy now belongs to this meeting under a new key, or to another job.
                plan.forget.append(key)
            } else if entry.endDate <= window.start {
                // Scrolled out of the past edge of the window: keep the copy, stop tracking it.
                plan.forget.append(key)
            } else if entry.startDate >= window.end {
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

    /// Re-links only events that match in every copied field. Title and time alone are too weak:
    /// a personal event with the same name and slot must not be taken over and later deleted.
    private static func takeAdoptable(
        matching payload: EventPayload,
        from adoptable: inout [MatchKey: [DestinationEvent]],
        excluding used: Set<String>
    ) -> DestinationEvent? {
        let key = MatchKey(payload)
        guard var candidates = adoptable[key],
              let index = candidates.lastIndex(where: { $0.payload == payload && !used.contains($0.id) }) else {
            return nil
        }
        let match = candidates.remove(at: index)
        if candidates.isEmpty {
            adoptable.removeValue(forKey: key)
        } else {
            adoptable[key] = candidates
        }
        return match
    }

    /// A destination copy is adopted by meeting identity only when the identity came from a
    /// join link. Two title-and-time look-alikes are not enough to take over an event that
    /// CalSync may not have created.
    private static func takeAdoptable(
        meeting key: String,
        from adoptable: inout [String: [DestinationEvent]],
        excluding used: Set<String>
    ) -> DestinationEvent? {
        guard var candidates = adoptable[key],
              let index = candidates.lastIndex(where: { !used.contains($0.id) }) else {
            return nil
        }
        let match = candidates.remove(at: index)
        if candidates.isEmpty {
            adoptable.removeValue(forKey: key)
        } else {
            adoptable[key] = candidates
        }
        return match
    }

    /// True when a source that had events on the previous run now has none. A source that was
    /// always empty is not an outage, and a source that was removed is not in `current`.
    static func hasSuspiciousEmptySource(
        current: [String: Int],
        previous: [String: Int]
    ) -> Bool {
        current.contains { id, count in
            count == 0 && (previous[id] ?? 0) > 0
        }
    }

    /// Returns the number of deletions when a run looks like a source-account outage rather than
    /// a real cleanup, and the caller should stop and ask first.
    ///
    /// A source that still exists but returns no events is exactly what a temporarily unavailable
    /// Exchange or iCloud account looks like. Deleting the whole mirror in that state is the most
    /// damaging thing this app could do. For a merge job, one empty source is enough to stop:
    /// its unique meetings would otherwise disappear while the other source still looks healthy.
    static func blockedDeletionCount(
        in plan: SyncPlan,
        sourceCount: Int,
        hasEmptySource: Bool = false
    ) -> Int? {
        let deletions = plan.deletionCount
        guard deletions > 0 else { return nil }
        if sourceCount == 0 || hasEmptySource { return deletions }
        // A large removal is suspicious when more than half of the previously tracked events
        // would disappear in one run.
        if deletions * 2 > sourceCount + deletions {
            return deletions
        }
        return nil
    }
}
