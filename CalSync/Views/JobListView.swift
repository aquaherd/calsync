import EventKit
import SwiftUI

struct JobListView: View {
    @Environment(AppModel.self) private var model
    @State private var editorJob: SyncJob?

    var body: some View {
        List {
            ForEach(model.jobs) { job in
                Button {
                    editorJob = job
                } label: {
                    JobRow(job: job)
                }
                .tint(.primary)
                .swipeActions(edge: .leading) {
                    Button("Sync", systemImage: "arrow.triangle.2.circlepath") {
                        Task { await model.sync(job.id) }
                    }
                    .tint(.accentColor)
                }
            }
            .onDelete(perform: model.delete(atOffsets:))
        }
        .overlay {
            if model.jobs.isEmpty {
                ContentUnavailableView {
                    Label("No Syncs", systemImage: "calendar.badge.plus")
                } description: {
                    Text("Add a sync to copy events from one or more calendars, such as Outlook, to another, such as iCloud.")
                } actions: {
                    Button("Add Sync") { editorJob = SyncJob() }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .refreshable { await model.syncAll() }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Sync All", systemImage: "arrow.triangle.2.circlepath") {
                    Task { await model.syncAll() }
                }
                .disabled(model.jobs.isEmpty || !model.runningJobs.isEmpty)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add Sync", systemImage: "plus") { editorJob = SyncJob() }
            }
        }
        .sheet(item: $editorJob) { job in
            JobEditorView(job: job, isNew: !model.jobs.contains { $0.id == job.id })
        }
        .alert(
            "Removal Stopped",
            isPresented: Binding(
                get: { model.pendingMassDeletion != nil },
                set: { _ in }
            ),
            presenting: model.pendingMassDeletion
        ) { request in
            Button("Remove Anyway", role: .destructive) {
                Task { await model.confirmMassDeletion() }
            }
            Button("Cancel", role: .cancel) {
                model.cancelMassDeletion()
            }
        } message: { request in
            Text(
                String.localizedStringWithFormat(
                    NSLocalizedString(
                        "“%@” would remove copied events (%lld) because a source calendar looks empty or much smaller. Check the source account first.",
                        comment: ""
                    ),
                    model.jobDescription(for: request.jobID),
                    request.count
                )
            )
        }
    }
}

private struct JobRow: View {
    @Environment(AppModel.self) private var model
    let job: SyncJob

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                if job.sources.isEmpty {
                    Text("No source")
                } else {
                    ForEach(job.sources) { source in
                        CalendarLabel(
                            calendar: model.calendar(withID: source.calendarID),
                            fallbackTitle: source.calendarTitle
                        )
                    }
                }
                Label {
                    CalendarLabel(
                        calendar: model.calendar(withID: job.destinationCalendarID),
                        fallbackTitle: job.destinationCalendarTitle
                    )
                } icon: {
                    Image(systemName: "arrow.turn.down.right").foregroundStyle(.secondary)
                }
                .labelStyle(.titleAndIcon)
                status
                    .font(.caption)
                    .foregroundStyle(job.lastResult?.error == nil ? Color.secondary : Color.red)
            }
            Spacer()
            if model.runningJobs.contains(job.id) {
                ProgressView()
            } else if !job.isEnabled {
                Image(systemName: "pause.circle").foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder private var status: some View {
        if let result = job.lastResult {
            Text(verbatim: result.date.formatted(.relative(presentation: .named)) + " · " + result.summary)
        } else {
            Text("Not synced yet")
        }
    }
}

struct CalendarLabel: View {
    let calendar: EKCalendar?
    var fallbackTitle: String? = nil

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(calendar.map { Color(cgColor: $0.cgColor) } ?? .gray)
                .frame(width: 10, height: 10)
            Text(calendar?.title ?? fallbackTitle ?? String(localized: "Missing calendar"))
                .lineLimit(1)
            if calendar == nil {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
            if let source = calendar?.source.title {
                Text(source)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}
