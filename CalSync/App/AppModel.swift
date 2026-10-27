import EventKit
import Foundation
import Observation

struct CalendarGroup: Identifiable {
    let id: String
    let title: String
    let calendars: [EKCalendar]
}

struct MassDeletionRequest: Identifiable, Hashable, Sendable {
    let id = UUID()
    let jobID: UUID
    let count: Int
}

enum StorageError: LocalizedError {
    case saveFailed

    var errorDescription: String? {
        String(localized: "CalSync could not save its syncs. Check that the device has free storage.")
    }
}

@Observable
final class AppModel {
    static let shared = AppModel()

    let eventStore = EKEventStore()
    private(set) var authorization = EKEventStore.authorizationStatus(for: .event)
    private(set) var calendars: [EKCalendar] = []
    private(set) var jobs: [SyncJob] = []
    private(set) var runningJobs: Set<UUID> = []
    /// A removal waiting for the user to confirm it.
    private(set) var pendingMassDeletion: MassDeletionRequest?
    /// A load or save problem that should not be silent.
    private(set) var storageError: String?

    private let jobsURL: URL
    private let mappings: MappingStore

    init(directory: URL = URL.applicationSupportDirectory.appending(path: "CalSync", directoryHint: .isDirectory)) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        jobsURL = directory.appending(path: "jobs.json")
        mappings = MappingStore(directory: directory.appending(path: "Mappings", directoryHint: .isDirectory))

        if FileManager.default.fileExists(atPath: jobsURL.path) {
            do {
                jobs = try JSONDecoder().decode([SyncJob].self, from: Data(contentsOf: jobsURL))
            } catch {
                let backup = directory.appending(path: "jobs.corrupt-\(Int(Date.now.timeIntervalSince1970)).json")
                try? FileManager.default.moveItem(at: jobsURL, to: backup)
                storageError = String.localizedStringWithFormat(
                    NSLocalizedString(
                        "Could not read the saved syncs. The previous file was kept as %@.",
                        comment: ""
                    ),
                    backup.lastPathComponent
                )
            }
        }
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
        repairCalendarReferences()
    }

    func calendar(withID id: String) -> EKCalendar? {
        calendars.first { $0.calendarIdentifier == id }
    }

    func calendarGroups(writableOnly: Bool, excluding excludedIDs: Set<String> = []) -> [CalendarGroup] {
        let filtered = calendars.filter {
            (!writableOnly || $0.allowsContentModifications) && !excludedIDs.contains($0.calendarIdentifier)
        }
        let grouped = Dictionary(grouping: filtered) { $0.source.sourceIdentifier }
        return grouped.map { id, calendars in
            CalendarGroup(id: id, title: calendars[0].source.title, calendars: calendars)
        }
        .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    /// Account removal and re-adding gives its calendars new identifiers. Reconnect a job by
    /// title, but only when the match is unambiguous.
    private func repairCalendarReferences() {
        var changed = false

        for index in jobs.indices {
            for sourceIndex in jobs[index].sources.indices {
                let source = jobs[index].sources[sourceIndex]
                if let calendar = calendar(withID: source.calendarID) {
                    if source.calendarTitle != calendar.title
                        || source.accountID != calendar.source.sourceIdentifier
                        || source.accountTitle != calendar.source.title {
                        jobs[index].sources[sourceIndex].calendarTitle = calendar.title
                        jobs[index].sources[sourceIndex].accountID = calendar.source.sourceIdentifier
                        jobs[index].sources[sourceIndex].accountTitle = calendar.source.title
                        changed = true
                    }
                } else if let calendar = matchingCalendar(
                    title: source.calendarTitle,
                    accountID: source.accountID,
                    accountTitle: source.accountTitle
                ), calendar.calendarIdentifier != jobs[index].destinationCalendarID,
                   !jobs[index].sources.contains(where: { $0.calendarID == calendar.calendarIdentifier }) {
                    jobs[index].sources[sourceIndex].calendarID = calendar.calendarIdentifier
                    jobs[index].sources[sourceIndex].calendarTitle = calendar.title
                    jobs[index].sources[sourceIndex].accountID = calendar.source.sourceIdentifier
                    jobs[index].sources[sourceIndex].accountTitle = calendar.source.title
                    changed = true
                }
            }

            // A source that reconnected to the same calendar as another would feed the same
            // events twice.
            var seenSources = Set<String>()
            let sourceCount = jobs[index].sources.count
            jobs[index].sources.removeAll { !seenSources.insert($0.calendarID).inserted }
            if jobs[index].sources.count != sourceCount { changed = true }

            if let calendar = calendar(withID: jobs[index].destinationCalendarID) {
                if jobs[index].destinationCalendarTitle != calendar.title
                    || jobs[index].destinationAccountID != calendar.source.sourceIdentifier
                    || jobs[index].destinationAccountTitle != calendar.source.title {
                    jobs[index].destinationCalendarTitle = calendar.title
                    jobs[index].destinationAccountID = calendar.source.sourceIdentifier
                    jobs[index].destinationAccountTitle = calendar.source.title
                    changed = true
                }
            } else if let calendar = matchingCalendar(
                title: jobs[index].destinationCalendarTitle,
                accountID: jobs[index].destinationAccountID,
                accountTitle: jobs[index].destinationAccountTitle
            ), !jobs[index].sources.contains(where: { $0.calendarID == calendar.calendarIdentifier }) {
                jobs[index].destinationCalendarID = calendar.calendarIdentifier
                jobs[index].destinationCalendarTitle = calendar.title
                jobs[index].destinationAccountID = calendar.source.sourceIdentifier
                jobs[index].destinationAccountTitle = calendar.source.title
                changed = true
            }
        }

        if changed { _ = persistJobs() }
    }

    private func matchingCalendar(title: String?, accountID: String?, accountTitle: String?) -> EKCalendar? {
        guard let title else { return nil }
        var candidates = calendars.filter {
            $0.title.localizedCaseInsensitiveCompare(title) == .orderedSame
        }
        // If the account name is known, never silently reconnect a calendar to a different
        // account that happens to use the same calendar name.
        if let accountTitle, !accountTitle.isEmpty {
            candidates = candidates.filter { $0.source.title == accountTitle }
        }
        if candidates.count == 1 { return candidates[0] }
        if let accountID {
            let inAccount = candidates.filter { $0.source.sourceIdentifier == accountID }
            if inAccount.count == 1 { return inAccount[0] }
        }
        return nil
    }

    // MARK: - Jobs

    func save(_ job: SyncJob, removeOldCopies: Bool = false) throws {
        var job = job
        job.sources.removeAll { $0.calendarID.isEmpty }
        for index in job.sources.indices {
            if let calendar = calendar(withID: job.sources[index].calendarID) {
                job.sources[index].calendarTitle = calendar.title
                job.sources[index].accountID = calendar.source.sourceIdentifier
                job.sources[index].accountTitle = calendar.source.title
            }
        }
        if let calendar = calendar(withID: job.destinationCalendarID) {
            job.destinationCalendarTitle = calendar.title
            job.destinationAccountID = calendar.source.sourceIdentifier
            job.destinationAccountTitle = calendar.source.title
        }

        if let index = jobs.firstIndex(where: { $0.id == job.id }) {
            let old = jobs[index]
            let calendarsChanged = old.destinationCalendarID != job.destinationCalendarID
                || Set(old.sources.map(\.calendarID)) != Set(job.sources.map(\.calendarID))
            if calendarsChanged {
                if removeOldCopies {
                    _ = try SyncEngine(store: eventStore, mappings: mappings).removeCopies(of: old)
                }
                // The old mapping no longer describes this job. Keeping it would either update
                // events in the wrong calendar or delete copies it can no longer see.
                mappings.remove(for: job.id)
            }
            jobs[index] = job
        } else {
            jobs.append(job)
        }
        if pendingMassDeletion?.jobID == job.id { pendingMassDeletion = nil }
        guard persistJobs() else { throw StorageError.saveFailed }
    }

    func delete(_ jobID: UUID) {
        jobs.removeAll { $0.id == jobID }
        if pendingMassDeletion?.jobID == jobID { pendingMassDeletion = nil }
        mappings.remove(for: jobID)
        _ = persistJobs()
    }

    func delete(atOffsets offsets: IndexSet) {
        offsets.map { jobs[$0].id }.forEach(delete)
    }

    // MARK: - Sync

    func sync(_ jobID: UUID, allowMassDeletion: Bool = false) async {
        guard hasFullAccess,
              let job = jobs.first(where: { $0.id == jobID }),
              !runningJobs.contains(jobID) else { return }
        runningJobs.insert(jobID)
        defer { runningJobs.remove(jobID) }
        await Task.yield()

        let result: SyncResult
        do {
            result = try SyncEngine(store: eventStore, mappings: mappings)
                .run(job, allowMassDeletion: allowMassDeletion)
            if pendingMassDeletion?.jobID == jobID { pendingMassDeletion = nil }
        } catch SyncError.massDeletion(let count) {
            let error = SyncError.massDeletion(count)
            result = errorResult(for: job, message: error.localizedDescription, blockedDeletions: count)
            enqueueMassDeletion(jobID: jobID, count: count)
        } catch {
            result = errorResult(for: job, message: error.localizedDescription)
        }
        setResult(result, for: jobID)
    }

    func syncAll() async {
        refreshAuthorization()
        for job in jobs where job.isEnabled {
            await sync(job.id)
        }
    }

    /// Runs the blocked job after the user confirmed that the removals are intended.
    func confirmMassDeletion() async {
        guard let request = pendingMassDeletion else { return }
        pendingMassDeletion = nil
        await sync(request.jobID, allowMassDeletion: true)
    }

    func cancelMassDeletion() {
        pendingMassDeletion = nil
    }

    func dismissStorageError() {
        storageError = nil
    }

    func jobDescription(for jobID: UUID) -> String {
        guard let job = jobs.first(where: { $0.id == jobID }) else { return "" }
        let sources = job.sources.compactMap { source in
            calendar(withID: source.calendarID)?.title ?? source.calendarTitle
        }
        let source = sources.isEmpty ? "?" : sources.joined(separator: " + ")
        let destination = calendar(withID: job.destinationCalendarID)?.title ?? job.destinationCalendarTitle ?? ""
        return "\(source) → \(destination)"
    }

    func removeCopies(of jobID: UUID) throws -> Int {
        guard let job = jobs.first(where: { $0.id == jobID }) else { return 0 }
        let removed = try SyncEngine(store: eventStore, mappings: mappings).removeCopies(of: job)
        if pendingMassDeletion?.jobID == jobID { pendingMassDeletion = nil }
        setResult(nil, for: jobID)
        return removed
    }

    private func enqueueMassDeletion(jobID: UUID, count: Int) {
        // Keep one request in front of the user. Other blocked jobs keep their error in
        // `lastResult` and ask again on the next sync.
        guard pendingMassDeletion == nil || pendingMassDeletion?.jobID == jobID else { return }
        pendingMassDeletion = MassDeletionRequest(jobID: jobID, count: count)
    }

    /// An error run still knows how many events each source had last time. Keeping that around
    /// lets the next run tell an empty source from an account that was briefly unavailable.
    private func errorResult(for job: SyncJob, message: String, blockedDeletions: Int = 0) -> SyncResult {
        var result = SyncResult()
        result.error = message
        result.blockedDeletions = blockedDeletions
        result.sourceCounts = job.lastResult?.sourceCounts ?? [:]
        return result
    }

    private func setResult(_ result: SyncResult?, for jobID: UUID) {
        guard let index = jobs.firstIndex(where: { $0.id == jobID }) else { return }
        jobs[index].lastResult = result
        _ = persistJobs()
    }

    @discardableResult
    private func persistJobs() -> Bool {
        do {
            let data = try JSONEncoder().encode(jobs)
            try data.write(
                to: jobsURL,
                options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
            )
            return true
        } catch {
            storageError = StorageError.saveFailed.localizedDescription
            return false
        }
    }
}
