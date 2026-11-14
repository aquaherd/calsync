import EventKit
import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Group {
            switch model.authorization {
            case .fullAccess:
                JobsView()
            case .notDetermined:
                NavigationStack {
                    AccessRequestView()
                        .navigationTitle("CalSync")
                }
            default:
                NavigationStack {
                    AccessDeniedView()
                        .navigationTitle("CalSync")
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .EKEventStoreChanged)) { _ in
            model.refreshCalendars()
        }
        .alert(
            "CalSync Storage",
            isPresented: Binding(
                get: { model.storageError != nil },
                set: { if !$0 { model.dismissStorageError() } }
            )
        ) {
            Button("OK") { model.dismissStorageError() }
        } message: {
            Text(model.storageError ?? "")
        }
    }
}

private struct AccessRequestView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ContentUnavailableView {
            Label("Calendar Access", systemImage: "calendar.badge.checkmark")
        } description: {
            Text("CalSync needs full access to your calendars to read events from one calendar and copy them to another.")
        } actions: {
            Button("Allow Access") {
                Task { await model.requestAccess() }
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

private struct AccessDeniedView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        ContentUnavailableView {
            Label("No Calendar Access", systemImage: "calendar.badge.exclamationmark")
        } description: {
            Text("Allow CalSync full access to calendars in Settings to copy events.")
        } actions: {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

#Preview {
    ContentView().environment(AppModel.shared)
}
