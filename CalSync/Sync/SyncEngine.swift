import EventKit
import Foundation

enum SyncError: LocalizedError {
    case sourceMissing(String?)
    case destinationMissing
    case destinationReadOnly
    case sameCalendar
    case massDeletion(Int)

    var errorDescription: String? {
        switch self {
        case .sourceMissing(let title):
            if let title, !title.isEmpty {
                String.localizedStringWithFormat(
                    NSLocalizedString("Source calendar “%@” not found.", comment: ""),
                    title
                )
            } else {
                String(localized: "Source calendar not found.")
            }
        case .destinationMissing: String(localized: "Destination calendar not found.")
        case .destinationReadOnly: String(localized: "Destination calendar is read-only.")
        case .sameCalendar: String(localized: "Source and destination must differ.")
        case .massDeletion(let count):
            String.localizedStringWithFormat(
                NSLocalizedString(
                    "Stopped before removing copied events (%lld) because a source calendar looks empty or much smaller. Check the source account, then confirm the removal.",
                    comment: ""
                ),
                count
            )
        }
    }
}

/// Applies `SyncPlanner` decisions to EventKit.
struct SyncEngine {
    let store: EKEventStore
    let mappings: MappingStore

    /// - Parameter allowMassDeletion: Set only after the user confirmed that a very large removal
    ///   is intended. Background runs never set it.
    func run(_ job: SyncJob, now: Date = .now, allowMassDeletion: Bool = false) throws -> SyncResult {
        guard !job.sources.isEmpty else { throw SyncError.sourceMissing(nil) }
        guard !job.sources.contains(where: { $0.calendarID == job.destinationCalendarID }) else {
            throw SyncError.sameCalendar
        }
        guard let destination = store.calendar(withIdentifier: job.destinationCalendarID) else { throw SyncError.destinationMissing }
        guard destination.allowsContentModifications else { throw SyncError.destinationReadOnly }

        let window = job.window(now: now)
        var occurrences: [SourceOccurrence] = []
        var sourceCounts: [String: Int] = [:]
        for source in job.sources {
            guard let calendar = store.calendar(withIdentifier: source.calendarID) else {
                throw SyncError.sourceMissing(source.calendarTitle ?? source.calendarID)
            }
            let sourceEvents = events(in: calendar, window: window)
            sourceCounts[source.calendarID] = sourceEvents.count
            occurrences += sourceEvents.compactMap {
                occurrence(from: $0, options: job.options, merge: job.isMerge)
            }
        }
        // An empty source is only suspicious when it had events on the last run. A feed that
        // never had anything is simply empty, and blocking every removal would be noise.
        let previousCounts = job.lastResult?.sourceCounts ?? [:]
        let hasEmptySource = job.isMerge
            && SyncPlanner.hasSuspiciousEmptySource(current: sourceCounts, previous: previousCounts)
        var mapping = try mappings.load(for: job.id)

        let existingIDs = Set(mapping.values.compactMap { entry -> String? in
            guard let event = store.event(withIdentifier: entry.destinationID),
                  event.calendar?.calendarIdentifier == destination.calendarIdentifier else { return nil }
            return entry.destinationID
        })
        let destinationEvents = events(in: destination, window: window).compactMap { event -> DestinationEvent? in
            guard let id = event.eventIdentifier else { return nil }
            return DestinationEvent(id: id, payload: payload(from: event))
        }
        let claimedElsewhere = mappings.claimedDestinationIDs(excluding: job.id)

        let plan = SyncPlanner.plan(
            source: occurrences,
            mapping: mapping,
            existingDestinationIDs: existingIDs,
            claimedDestinationIDs: claimedElsewhere,
            destinationEvents: destinationEvents,
            window: window,
            deleteRemoved: job.options.deleteRemoved,
            mergeDuplicates: job.isMerge
        )

        if !allowMassDeletion,
           let blocked = SyncPlanner.blockedDeletionCount(
            in: plan,
            sourceCount: occurrences.count,
            hasEmptySource: hasEmptySource
           ) {
            throw SyncError.massDeletion(blocked)
        }

        var result = SyncResult(date: now, unchanged: plan.unchanged)
        result.sourceCounts = sourceCounts
        var created: [(key: String, event: EKEvent, payload: EventPayload)] = []

        for key in plan.forget { mapping.removeValue(forKey: key) }

        for action in plan.actions {
            do {
                switch action {
                case .create(let occurrence):
                    let event = EKEvent(eventStore: store)
                    event.calendar = destination
                    apply(occurrence.payload, to: event)
                    try store.save(event, span: .thisEvent, commit: false)
                    created.append((occurrence.key, event, occurrence.payload))
                case .update(let id, let occurrence):
                    guard let event = store.event(withIdentifier: id) else {
                        result.failed += 1
                        appendFailure(String(localized: "A copied event could not be found and will be recreated."), to: &result)
                        continue
                    }
                    apply(occurrence.payload, to: event)
                    try store.save(event, span: .thisEvent, commit: false)
                    mapping[occurrence.key] = MappingEntry(destinationID: id, payload: occurrence.payload)
                    result.updated += 1
                case .delete(let id, let key):
                    if let event = store.event(withIdentifier: id) {
                        try store.remove(event, span: .thisEvent, commit: false)
                    }
                    mapping.removeValue(forKey: key)
                    result.deleted += 1
                }
            } catch {
                result.failed += 1
                appendFailure(error.localizedDescription, to: &result)
            }
        }

        try store.commit()

        for item in created {
            guard let id = item.event.eventIdentifier else {
                result.failed += 1
                appendFailure(String(localized: "A copied event could not be saved."), to: &result)
                continue
            }
            mapping[item.key] = MappingEntry(destinationID: id, payload: item.payload)
            result.created += 1
        }

        try mappings.save(mapping, for: job.id)
        return result
    }

    /// Deletes every copy this job has created and forgets them.
    func removeCopies(of job: SyncJob) throws -> Int {
        let mapping = try mappings.load(for: job.id)
        var removed = 0
        var removedIDs = Set<String>()
        for entry in mapping.values {
            // An old and a new key can point at the same copy after a mapping re-key.
            guard removedIDs.insert(entry.destinationID).inserted else { continue }
            guard let event = store.event(withIdentifier: entry.destinationID),
                  event.calendar?.calendarIdentifier == job.destinationCalendarID else { continue }
            try store.remove(event, span: .thisEvent, commit: false)
            removed += 1
        }
        try store.commit()
        mappings.remove(for: job.id)
        return removed
    }

    // MARK: - EventKit conversion

    private func events(in calendar: EKCalendar, window: DateInterval) -> [EKEvent] {
        let predicate = store.predicateForEvents(withStart: window.start, end: window.end, calendars: [calendar])
        return store.events(matching: predicate)
    }

    private func occurrence(from event: EKEvent, options: SyncOptions, merge: Bool) -> SourceOccurrence? {
        if options.skipAllDay && event.isAllDay { return nil }
        if options.skipDeclined {
            if event.status == .canceled { return nil }
            if event.attendees?.first(where: \.isCurrentUser)?.participantStatus == .declined { return nil }
        }

        var payload = payload(from: event)
        // The join link must be read before private mode or the org-only link filter removes it.
        let identity = merge ? MeetingIdentity.of(payload) : nil
        if options.privateMode {
            payload.title = options.privateTitle
            payload.location = nil
            payload.notes = nil
            payload.url = nil
        } else {
            if !options.copyLocation { payload.location = nil }
            if !options.copyNotes { payload.notes = nil }
            if !options.copyURL { payload.url = nil }
        }
        if !options.copyAlarms { payload.alarmOffsets = [] }
        payload = OrgOnlyLinkFilter.strip(from: payload, copyURL: options.copyURL)

        let key: String
        if let identity {
            // Every source that contains this meeting produces the same key, so the planner
            // copies it once and the mapping survives the meeting leaving one source.
            key = identity.key
        } else {
            let itemID = event.calendarItemExternalIdentifier ?? event.calendarItemIdentifier
            let occurrenceDate: Date = event.occurrenceDate ?? event.startDate
            key = "\(itemID)|\(Int(occurrenceDate.timeIntervalSince1970))"
        }
        return SourceOccurrence(
            key: key,
            payload: payload,
            hasStrongIdentity: identity?.isStrong ?? false
        )
    }

    private func payload(from event: EKEvent) -> EventPayload {
        EventPayload(
            title: event.title ?? "",
            startDate: event.startDate,
            endDate: event.endDate,
            isAllDay: event.isAllDay,
            timeZoneID: event.timeZone?.identifier,
            location: event.location.flatMap { $0.isEmpty ? nil : $0 },
            notes: event.notes.flatMap { $0.isEmpty ? nil : $0 },
            url: event.url,
            alarmOffsets: (event.alarms ?? []).filter { $0.absoluteDate == nil }.map(\.relativeOffset)
        )
    }

    private func apply(_ payload: EventPayload, to event: EKEvent) {
        event.title = payload.title
        event.isAllDay = payload.isAllDay
        event.timeZone = payload.timeZoneID.flatMap(TimeZone.init(identifier:))
        event.startDate = payload.startDate
        event.endDate = payload.endDate
        event.location = payload.location
        event.notes = payload.notes
        event.url = payload.url
        event.alarms = payload.alarmOffsets.isEmpty ? nil : payload.alarmOffsets.map { EKAlarm(relativeOffset: $0) }
    }

    private func appendFailure(_ message: String, to result: inout SyncResult) {
        guard result.failures.count < 5 else { return }
        result.failures.append(message)
    }
}
