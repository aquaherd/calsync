import BackgroundTasks
import SwiftUI

@main
struct CalSyncApp: App {
    @Environment(\.scenePhase) private var scenePhase
    private let model = AppModel.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(model)
        }
        .defaultSize(width: 1100, height: 800)
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                Task { await model.syncAll() }
            case .background:
                BackgroundRefresh.schedule()
            default:
                break
            }
        }
        .backgroundTask(.appRefresh(BackgroundRefresh.identifier)) {
            await AppModel.shared.syncAll()
            await BackgroundRefresh.schedule()
        }
    }
}

enum BackgroundRefresh {
    nonisolated static let identifier = (Bundle.main.bundleIdentifier ?? "calsync") + ".refresh"

    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = .now.addingTimeInterval(60 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }
}
