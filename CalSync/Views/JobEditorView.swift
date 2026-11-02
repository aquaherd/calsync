import EventKit
import SwiftUI

struct JobEditorView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var job: SyncJob
    @State private var confirmRemoveCopies = false
    @State private var confirmDelete = false
    @State private var confirmCalendarChange = false
    @State private var showingNewCalendar = false
    @State private var message: String?
    private let isNew: Bool
    private let original: SyncJob

    private static let pastChoices = [0, 1, 7, 14, 30, 90, 365]
    private static let aheadChoices = [7, 14, 30, 60, 90, 180, 365]

    init(job: SyncJob, isNew: Bool) {
        _job = State(initialValue: job)
        original = job
        self.isNew = isNew
    }

    private var calendarsChanged: Bool {
        Set(original.sources.map(\.calendarID)) != Set(job.sources.map(\.calendarID))
            || original.destinationCalendarID != job.destinationCalendarID
    }

    var body: some View {
        NavigationStack {
            Form {
                calendarsSection
                rangeSection
                detailsSection
                behaviorSection
                if let result = job.lastResult { lastSyncSection(result) }
                if !isNew { dangerSection }
            }
            .navigationTitle(isNew ? "New Sync" : "Edit Sync")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { requestSave() }
                        .disabled(!job.isValid)
                }
            }
            .onChange(of: job.destinationCalendarID) { _, newValue in
                // The pickers already exclude each other; this also covers a calendar that
                // reconnected after an account was removed and added again.
                if !newValue.isEmpty {
                    job.sources.removeAll { $0.calendarID == newValue }
                }
            }
            .confirmationDialog(
                "Calendars changed",
                isPresented: $confirmCalendarChange,
                titleVisibility: .visible
            ) {
                Button("Remove Old Copies", role: .destructive) { save(removeOldCopies: true) }
                Button("Keep Old Copies") { save(removeOldCopies: false) }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Copies already in the destination calendar stay unless you remove them. CalSync can no longer manage them afterwards.")
            }
            .alert("CalSync", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK") {}
            } message: {
                Text(message ?? "")
            }
            .sheet(isPresented: $showingNewCalendar) {
                NewCalendarSheet { calendar in
                    job.destinationCalendarID = calendar.calendarIdentifier
                }
            }
        }
    }

    private var calendarsSection: some View {
        Group {
            Section {
                if job.sources.isEmpty {
                    Text("Choose one or more source calendars.")
                        .foregroundStyle(.secondary)
                }
                ForEach(job.sources) { source in
                    HStack {
                        CalendarLabel(
                            calendar: model.calendar(withID: source.calendarID),
                            fallbackTitle: source.calendarTitle
                        )
                        Spacer()
                        Button(role: .destructive) {
                            job.sources.removeAll { $0.id == source.id }
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Remove Calendar")
                    }
                }
                Menu {
                    ForEach(model.calendarGroups(writableOnly: false, excluding: sourceExclusions)) { group in
                        Section(group.title) {
                            ForEach(group.calendars, id: \.calendarIdentifier) { calendar in
                                Button {
                                    addSource(calendar)
                                } label: {
                                    Text(verbatim: "\(calendar.title) — \(calendar.source.title)")
                                }
                            }
                        }
                    }
                } label: {
                    Label("Add Calendar", systemImage: "plus")
                }
            } header: {
                Text("From")
            } footer: {
                Text("Add more than one calendar to merge them. Meetings that appear in more than one source are copied once, using the first source's details.")
            }

            Section {
                Picker("To", selection: $job.destinationCalendarID) {
                    Text("Choose…").tag("")
                    ForEach(model.calendarGroups(
                        writableOnly: true,
                        excluding: Set(job.sources.map(\.calendarID))
                    )) { group in
                        Section(group.title) {
                            ForEach(group.calendars, id: \.calendarIdentifier) { calendar in
                                CalendarLabel(calendar: calendar).tag(calendar.calendarIdentifier)
                            }
                        }
                    }
                }
                if model.creatableSources.isEmpty {
                    Text("No account can create calendars. Add an iCloud account in Settings.")
                        .foregroundStyle(.secondary)
                } else {
                    Button {
                        showingNewCalendar = true
                    } label: {
                        Label("New Calendar…", systemImage: "plus")
                    }
                }
            } header: {
                Text("To")
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Outlook calendars appear here once your Outlook or Exchange account is added under Settings › Apps › Calendar › Calendar Accounts.")
                    Text("New calendars are created in iCloud or On My iPhone. Share one in Calendar to let someone else see it.")
                }
            }
        }
        .pickerStyle(.navigationLink)
    }

    private var sourceExclusions: Set<String> {
        Set(job.sources.map(\.calendarID)).union([job.destinationCalendarID])
    }

    private func addSource(_ calendar: EKCalendar) {
        guard calendar.calendarIdentifier != job.destinationCalendarID,
              !job.sources.contains(where: { $0.calendarID == calendar.calendarIdentifier }) else {
            return
        }
        job.sources.append(SourceCalendar(calendarID: calendar.calendarIdentifier))
    }

    private var rangeSection: some View {
        Section("Time Range") {
            Picker("Past", selection: $job.daysBack) {
                ForEach(Self.pastChoices, id: \.self) { Text(dayLabel($0)).tag($0) }
            }
            Picker("Ahead", selection: $job.daysAhead) {
                ForEach(Self.aheadChoices, id: \.self) { Text(dayLabel($0)).tag($0) }
            }
        }
    }

    private var detailsSection: some View {
        Section {
            Toggle("Private (Busy Only)", isOn: $job.options.privateMode)
            if job.options.privateMode {
                TextField("Title", text: $job.options.privateTitle)
            } else {
                Toggle("Copy Location", isOn: $job.options.copyLocation)
                Toggle("Copy Notes", isOn: $job.options.copyNotes)
                Toggle("Copy URL", isOn: $job.options.copyURL)
            }
            Toggle("Copy Alerts", isOn: $job.options.copyAlarms)
        } header: {
            Text("Details")
        } footer: {
            if job.options.privateMode {
                Text("Private mode copies only the time slot, using the title above.")
            } else if !job.options.copyURL {
                Text("When Copy URL is off, Teams join links and their join boilerplate are removed from notes and location too.")
            }
        }
    }

    private var behaviorSection: some View {
        Section {
            Toggle("Skip Declined & Canceled", isOn: $job.options.skipDeclined)
            Toggle("Skip All-Day Events", isOn: $job.options.skipAllDay)
            Toggle("Remove Deleted Events", isOn: $job.options.deleteRemoved)
            Toggle("Enabled", isOn: $job.isEnabled)
        } header: {
            Text("Behavior")
        } footer: {
            Text("Enabled syncs run when the app opens and periodically in the background. A very large removal is stopped until you confirm it.")
        }
    }

    private func lastSyncSection(_ result: SyncResult) -> some View {
        Section("Last Sync") {
            Text(result.summary)
            if !result.failures.isEmpty {
                ForEach(Array(result.failures.enumerated()), id: \.offset) { _, failure in
                    Text(failure)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var dangerSection: some View {
        Section {
            Button("Remove Copied Events", role: .destructive) { confirmRemoveCopies = true }
                .confirmationDialog("Remove all events this sync copied to the destination?", isPresented: $confirmRemoveCopies, titleVisibility: .visible) {
                    Button("Remove Copied Events", role: .destructive) {
                        do {
                            let count = try model.removeCopies(of: job.id)
                            message = String.localizedStringWithFormat(
                                NSLocalizedString("Removed %lld events.", comment: ""), count)
                        } catch {
                            message = error.localizedDescription
                        }
                    }
                }
            Button("Delete Sync", role: .destructive) { confirmDelete = true }
                .confirmationDialog("Delete this sync? Copied events stay in the destination calendar.", isPresented: $confirmDelete, titleVisibility: .visible) {
                    Button("Delete Sync", role: .destructive) {
                        model.delete(job.id)
                        dismiss()
                    }
                }
        }
    }

    private func requestSave() {
        if !isNew && calendarsChanged {
            confirmCalendarChange = true
        } else {
            save(removeOldCopies: false)
        }
    }

    private func save(removeOldCopies: Bool) {
        do {
            try model.save(job, removeOldCopies: removeOldCopies)
            let id = job.id
            dismiss()
            Task { await model.sync(id) }
        } catch {
            message = error.localizedDescription
        }
    }

    private func dayLabel(_ days: Int) -> String {
        switch days {
        case 0: String(localized: "None")
        case 1: String(localized: "1 day")
        case 365: String(localized: "1 year")
        default: String(localized: "\(days) days")
        }
    }
}
