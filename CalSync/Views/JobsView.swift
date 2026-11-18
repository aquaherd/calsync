import SwiftUI
import UIKit

struct JobsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var editorJob: SyncJob?
    @State private var sheetJob: SyncJob?
    @State private var didAutoSelect = false
    #if DEBUG
    @State private var didOpenDemoJob = false
    #endif

    // The iPad idiom check is required because a Pro Max iPhone in landscape is also `.regular` width.
    private var usesSplitLayout: Bool {
        UIDevice.current.userInterfaceIdiom == .pad && horizontalSizeClass == .regular
    }

    var body: some View {
        Group {
            if usesSplitLayout {
                splitLayout
            } else {
                compactLayout
            }
        }
        .onChange(of: model.jobs.map(\.id)) { oldIDs, ids in
            guard let id = editorJob?.id, oldIDs.contains(id), !ids.contains(id) else { return }
            editorJob = nil
        }
        .onChange(of: usesSplitLayout) { _, isSplit in
            if isSplit {
                if let job = sheetJob { editorJob = job }
                sheetJob = nil
            } else {
                // A sheet cannot stay presented across the layout change.
                sheetJob = nil
            }
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
        .onAppear {
            #if DEBUG
            openRequestedDemoJob()
            #endif
        }
    }

    #if DEBUG
    /// Opens a job from the editor launch flags used by the screenshot script.
    private func openRequestedDemoJob() {
        guard !didOpenDemoJob else { return }
        let arguments = ProcessInfo.processInfo.arguments
        let requestedJob: SyncJob?
        if arguments.contains("--demo-open-editor") {
            requestedJob = model.jobs.first
        } else if arguments.contains("--demo-new-sync") {
            requestedJob = SyncJob()
        } else {
            requestedJob = nil
        }
        guard let requestedJob else { return }
        didOpenDemoJob = true
        if usesSplitLayout {
            editorJob = requestedJob
        } else {
            sheetJob = requestedJob
        }
    }
    #endif

    private var splitLayout: some View {
        NavigationSplitView {
            JobListView(selectedJobID: editorJob?.id, onSelect: { editorJob = $0 })
                .navigationTitle("CalSync")
                .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 420)
        } detail: {
            if let job = editorJob {
                JobEditorView(
                    job: job,
                    isNew: !model.jobs.contains { $0.id == job.id },
                    onFinish: { action in
                        switch action {
                        case .save:
                            if let id = editorJob?.id {
                                editorJob = model.jobs.first { $0.id == id }
                            }
                        case .cancel, .delete:
                            editorJob = nil
                        }
                    }
                )
                .id(job.id)
            } else {
                ContentUnavailableView(
                    "No Sync Selected",
                    systemImage: "slider.horizontal.3",
                    description: Text("Select a sync to edit it.")
                )
            }
        }
        .onAppear {
            guard !didAutoSelect else { return }
            didAutoSelect = true
            if editorJob == nil { editorJob = model.jobs.first }
        }
    }

    private var compactLayout: some View {
        NavigationStack {
            JobListView(selectedJobID: nil, onSelect: { sheetJob = $0 })
                .navigationTitle("CalSync")
        }
        .sheet(item: $sheetJob) { job in
            JobEditorView(job: job, isNew: !model.jobs.contains { $0.id == job.id })
        }
    }
}

#Preview {
    JobsView().environment(AppModel.shared)
}
