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
                    Text("Add a sync to copy events from one calendar, such as Outlook, to another, such as iCloud.")
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
    }
}

private struct JobRow: View {
    @Environment(AppModel.self) private var model
    let job: SyncJob

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                CalendarLabel(calendar: model.calendar(withID: job.sourceCalendarID))
                Label {
                    CalendarLabel(calendar: model.calendar(withID: job.destinationCalendarID))
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
            Text("\(result.date, format: .relative(presentation: .named)) · \(result.summary)")
        } else {
            Text("Not synced yet")
        }
    }
}

struct CalendarLabel: View {
    let calendar: EKCalendar?

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(calendar.map { Color(cgColor: $0.cgColor) } ?? .gray)
                .frame(width: 10, height: 10)
            Text(calendar?.title ?? "Missing calendar")
                .lineLimit(1)
            if let source = calendar?.source.title {
                Text(source)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}
