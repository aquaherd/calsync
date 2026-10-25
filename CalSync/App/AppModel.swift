import EventKit
import Foundation
import Observation

struct CalendarGroup: Identifiable {
    let id: String
    let title: String
    let calendars: [EKCalendar]
}

@Observable
final class AppModel {
    static let shared = AppModel()

    let eventStore = EKEventStore()
    private(set) var authorization = EKEventStore.authorizationStatus(for: .event)
    private(set) var calendars: [EKCalendar] = []
    private(set) var jobs: [SyncJob]
    private(set) var runningJobs: Set<UUID> = []

    private let jobsURL: URL
    private let mappings: MappingStore

    init(directory: URL = URL.applicationSupportDirectory.appending(path: "CalSync", directoryHint: .isDirectory)) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        jobsURL = directory.appending(path: "jobs.json")
        mappings = MappingStore(directory: directory.appending(path: "Mappings", directoryHint: .isDirectory))
        jobs = (try? JSONDecoder().decode([SyncJob].self, from: Data(contentsOf: jobsURL))) ?? []
        refreshCalendars()
    }

    // MARK: - Access

    var hasFullAccess: Bool { authorization == .fullAccess }

    func requestAccess() async {
        _ = try? await eventStore.requestFullAccessToEvents()
        refreshAuthorization()
    }

    func refreshAuthorization() {
        authorization = EKEventStore.authorizationStatus(for: .event)
        refreshCalendars()
    }

    func refreshCalendars() {
        guard hasFullAccess else { calendars = []; return }
        eventStore.refreshSourcesIfNecessary()
        calendars = eventStore.calendars(for: .event).sorted {
            ($0.source.title, $0.title) < ($1.source.title, $1.title)
        }
    }

    func calendar(withID id: String) -> EKCalendar? {
        calendars.first { $0.calendarIdentifier == id }
    }

    func calendarGroups(writableOnly: Bool, excluding excludedID: String? = nil) -> [CalendarGroup] {
        let filtered = calendars.filter {
            (!writableOnly || $0.allowsContentModifications) && $0.calendarIdentifier != excludedID
        }
        let grouped = Dictionary(grouping: filtered) { $0.source.sourceIdentifier }
        return grouped.map { id, calendars in
            CalendarGroup(id: id, title: calendars[0].source.title, calendars: calendars)
        }
        .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    // MARK: - Jobs

    func save(_ job: SyncJob) {
        if let index = jobs.firstIndex(where: { $0.id == job.id }) {
            let old = jobs[index]
            if old.sourceCalendarID != job.sourceCalendarID || old.destinationCalendarID != job.destinationCalendarID {
                mappings.remove(for: job.id)
            }
            jobs[index] = job
        } else {
            jobs.append(job)
        }
        persistJobs()
    }

    func delete(_ jobID: UUID) {
        jobs.removeAll { $0.id == jobID }
        mappings.remove(for: jobID)
        persistJobs()
    }

    func delete(atOffsets offsets: IndexSet) {
        offsets.map { jobs[$0].id }.forEach(delete)
    }

    // MARK: - Sync

    func sync(_ jobID: UUID) async {
        guard hasFullAccess,
              let job = jobs.first(where: { $0.id == jobID }),
              !runningJobs.contains(jobID) else { return }
        runningJobs.insert(jobID)
        defer { runningJobs.remove(jobID) }
        await Task.yield()

        let result: SyncResult
        do {
            result = try SyncEngine(store: eventStore, mappings: mappings).run(job)
        } catch {
            result = SyncResult(error: error.localizedDescription)
        }
        setResult(result, for: jobID)
    }

    func syncAll() async {
        refreshAuthorization()
        for job in jobs where job.isEnabled {
            await sync(job.id)
        }
    }

    func removeCopies(of jobID: UUID) throws -> Int {
        guard let job = jobs.first(where: { $0.id == jobID }) else { return 0 }
        let removed = try SyncEngine(store: eventStore, mappings: mappings).removeCopies(of: job)
        setResult(nil, for: jobID)
        return removed
    }

    private func setResult(_ result: SyncResult?, for jobID: UUID) {
        guard let index = jobs.firstIndex(where: { $0.id == jobID }) else { return }
        jobs[index].lastResult = result
        persistJobs()
    }

    private func persistJobs() {
        try? JSONEncoder().encode(jobs).write(to: jobsURL, options: .atomic)
    }
}
