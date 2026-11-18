#if DEBUG
import EventKit
import Foundation

/// Debug-only demo data for App Store screenshots.
///
/// The app runs this only when it is launched with `--seed-demo`. A marker file in
/// Application Support keeps repeated launches from adding duplicate calendars, events
/// or syncs.
enum DemoData {
    private static let calendarTitles = ["Work", "Side Project", "Personal", "Family"]

    private struct DemoEvent {
        let title: String
        let day: Int
        let hour: Int
        let minute: Int
        let duration: Int
        let location: String?
        let notes: String?
    }

    private static let workEvents = [
        DemoEvent(title: "Design Review", day: 0, hour: 9, minute: 30, duration: 60,
                  location: "Room 3.14", notes: nil),
        DemoEvent(title: "Sprint Planning", day: 1, hour: 10, minute: 0, duration: 90,
                  location: nil, notes: "Agenda: roadmap, open bugs, release checklist."),
        DemoEvent(title: "1:1 with Nina", day: 2, hour: 14, minute: 0, duration: 30,
                  location: nil, notes: nil),
        DemoEvent(title: "Client Call", day: 5, hour: 15, minute: 0, duration: 45,
                  location: "Teams", notes: nil),
    ]

    private static let sideProjectEvents = [
        DemoEvent(title: "Prototype Review", day: 0, hour: 16, minute: 0, duration: 45,
                  location: nil, notes: nil),
        DemoEvent(title: "Roadmap Workshop", day: 4, hour: 11, minute: 0, duration: 90,
                  location: "Studio", notes: nil),
    ]

    /// Seeds demo calendars, events and syncs when `--seed-demo` is passed.
    static func seed(into model: AppModel) {
        guard ProcessInfo.processInfo.arguments.contains("--seed-demo"),
              model.hasFullAccess else { return }

        let supportDirectory = URL.applicationSupportDirectory
            .appending(path: "CalSync", directoryHint: .isDirectory)
        let marker = supportDirectory.appending(path: "demo-seeded")
        guard !FileManager.default.fileExists(atPath: marker.path) else { return }

        try? FileManager.default.createDirectory(at: supportDirectory, withIntermediateDirectories: true)

        guard let source = model.eventStore.sources.first(where: { $0.sourceType == .local }) else {
            return
        }

        var calendarIDs: [String: String] = [:]
        for title in calendarTitles {
            if let existing = model.calendars.first(where: {
                $0.source.sourceIdentifier == source.sourceIdentifier
                    && $0.title.localizedCaseInsensitiveCompare(title) == .orderedSame
            }) {
                calendarIDs[title] = existing.calendarIdentifier
                continue
            }
            guard let calendar = try? model.createCalendar(title: title, sourceID: source.sourceIdentifier) else {
                return
            }
            calendarIDs[title] = calendar.calendarIdentifier
        }

        guard let work = calendar(named: "Work", ids: calendarIDs, in: model),
              let sideProject = calendar(named: "Side Project", ids: calendarIDs, in: model),
              let personal = calendar(named: "Personal", ids: calendarIDs, in: model),
              let family = calendar(named: "Family", ids: calendarIDs, in: model) else {
            return
        }

        add(workEvents, to: work, in: model.eventStore)
        add(sideProjectEvents, to: sideProject, in: model.eventStore)

        var single = SyncJob()
        single.sources = [SourceCalendar(calendarID: work.calendarIdentifier)]
        single.destinationCalendarID = personal.calendarIdentifier
        single.daysBack = 7
        single.daysAhead = 30
        single.isEnabled = true
        try? model.save(single)

        var merge = SyncJob()
        merge.sources = [
            SourceCalendar(calendarID: work.calendarIdentifier),
            SourceCalendar(calendarID: sideProject.calendarIdentifier),
        ]
        merge.destinationCalendarID = family.calendarIdentifier
        merge.daysBack = 14
        merge.daysAhead = 60
        merge.isEnabled = true
        try? model.save(merge)

        // Written last so an interrupted seed runs again on the next launch.
        FileManager.default.createFile(atPath: marker.path, contents: Data())
    }

    private static func calendar(named title: String, ids: [String: String], in model: AppModel) -> EKCalendar? {
        guard let id = ids[title] else { return nil }
        return model.calendar(withID: id)
    }

    private static func add(_ events: [DemoEvent], to calendar: EKCalendar, in store: EKEventStore) {
        let calendarSystem = Calendar.current
        let today = calendarSystem.startOfDay(for: .now)
        for demo in events {
            guard let day = calendarSystem.date(byAdding: .day, value: demo.day, to: today),
                  let start = calendarSystem.date(
                    bySettingHour: demo.hour,
                    minute: demo.minute,
                    second: 0,
                    of: day
                  ),
                  let end = calendarSystem.date(byAdding: .minute, value: demo.duration, to: start) else {
                continue
            }
            let event = EKEvent(eventStore: store)
            event.calendar = calendar
            event.title = demo.title
            event.startDate = start
            event.endDate = end
            event.location = demo.location
            event.notes = demo.notes
            try? store.save(event, span: .thisEvent)
        }
    }
}
#endif
