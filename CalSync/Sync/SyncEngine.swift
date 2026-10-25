import EventKit
import Foundation

enum SyncError: LocalizedError {
    case sourceMissing
    case destinationMissing
    case destinationReadOnly
    case sameCalendar

    var errorDescription: String? {
        switch self {
        case .sourceMissing: "Source calendar not found."
        case .destinationMissing: "Destination calendar not found."
        case .destinationReadOnly: "Destination calendar is read-only."
        case .sameCalendar: "Source and destination must differ."
        }
    }
}

/// Applies `SyncPlanner` decisions to EventKit.
struct SyncEngine {
    let store: EKEventStore
    let mappings: MappingStore

    func run(_ job: SyncJob, now: Date = .now) throws -> SyncResult {
        guard job.sourceCalendarID != job.destinationCalendarID else { throw SyncError.sameCalendar }
        guard let source = store.calendar(withIdentifier: job.sourceCalendarID) else { throw SyncError.sourceMissing }
        guard let destination = store.calendar(withIdentifier: job.destinationCalendarID) else { throw SyncError.destinationMissing }
        guard destination.allowsContentModifications else { throw SyncError.destinationReadOnly }

        let window = job.window(now: now)
        let occurrences = events(in: source, window: window).compactMap { occurrence(from: $0, options: job.options) }
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

        let plan = SyncPlanner.plan(
            source: occurrences,
            mapping: mapping,
            existingDestinationIDs: existingIDs,
            destinationEvents: destinationEvents,
            window: window,
            deleteRemoved: job.options.deleteRemoved
        )

        var result = SyncResult(date: now, unchanged: plan.unchanged)
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
                    guard let event = store.event(withIdentifier: id) else { result.failed += 1; continue }
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
            }
        }

        try store.commit()

        for item in created {
            guard let id = item.event.eventIdentifier else { result.failed += 1; continue }
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
        for entry in mapping.values {
            guard let event = store.event(withIdentifier: entry.destinationID) else { continue }
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

    private func occurrence(from event: EKEvent, options: SyncOptions) -> SourceOccurrence? {
        if options.skipAllDay && event.isAllDay { return nil }
        if options.skipDeclined {
            if event.status == .canceled { return nil }
            if event.attendees?.first(where: \.isCurrentUser)?.participantStatus == .declined { return nil }
        }

        var payload = payload(from: event)
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

        let itemID = event.calendarItemExternalIdentifier ?? event.calendarItemIdentifier
        let occurrenceDate: Date = event.occurrenceDate ?? event.startDate
        return SourceOccurrence(key: "\(itemID)|\(Int(occurrenceDate.timeIntervalSince1970))", payload: payload)
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
}
