import EventKit
import SwiftUI

struct JobEditorView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var job: SyncJob
    @State private var confirmRemoveCopies = false
    @State private var confirmDelete = false
    @State private var message: String?
    private let isNew: Bool

    private static let pastChoices = [0, 1, 7, 14, 30, 90, 365]
    private static let aheadChoices = [7, 14, 30, 60, 90, 180, 365]

    init(job: SyncJob, isNew: Bool) {
        _job = State(initialValue: job)
        self.isNew = isNew
    }

    var body: some View {
        NavigationStack {
            Form {
                calendarsSection
                rangeSection
                detailsSection
                behaviorSection
                if !isNew { dangerSection }
            }
            .navigationTitle(isNew ? "New Sync" : "Edit Sync")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        model.save(job)
                        let id = job.id
                        dismiss()
                        Task { await model.sync(id) }
                    }
                    .disabled(!job.isValid)
                }
            }
            .onChange(of: job.sourceCalendarID) { _, newValue in
                if job.destinationCalendarID == newValue { job.destinationCalendarID = "" }
            }
            .alert("CalSync", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK") {}
            } message: {
                Text(message ?? "")
            }
        }
    }

    private var calendarsSection: some View {
        Section {
            Picker("From", selection: $job.sourceCalendarID) {
                Text("Choose…").tag("")
                ForEach(model.calendarGroups(writableOnly: false)) { group in
                    Section(group.title) {
                        ForEach(group.calendars, id: \.calendarIdentifier) { calendar in
                            CalendarLabel(calendar: calendar).tag(calendar.calendarIdentifier)
                        }
                    }
                }
            }
            Picker("To", selection: $job.destinationCalendarID) {
                Text("Choose…").tag("")
                ForEach(model.calendarGroups(writableOnly: true, excluding: job.sourceCalendarID)) { group in
                    Section(group.title) {
                        ForEach(group.calendars, id: \.calendarIdentifier) { calendar in
                            CalendarLabel(calendar: calendar).tag(calendar.calendarIdentifier)
                        }
                    }
                }
            }
        } header: {
            Text("Calendars")
        } footer: {
            Text("Outlook calendars appear here once your Outlook or Exchange account is added under Settings › Apps › Calendar › Calendar Accounts.")
        }
        .pickerStyle(.navigationLink)
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
            Text("Private mode copies only the time slot, using the title above.")
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
            Text("Enabled syncs run when the app opens and periodically in the background.")
        }
    }

    private var dangerSection: some View {
        Section {
            Button("Remove Copied Events", role: .destructive) { confirmRemoveCopies = true }
                .confirmationDialog("Remove all events this sync copied to the destination?", isPresented: $confirmRemoveCopies, titleVisibility: .visible) {
                    Button("Remove Copied Events", role: .destructive) {
                        do {
                            let count = try model.removeCopies(of: job.id)
                            message = "Removed \(count) events."
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

    private func dayLabel(_ days: Int) -> String {
        switch days {
        case 0: "None"
        case 1: "1 day"
        case 365: "1 year"
        default: "\(days) days"
        }
    }
}
