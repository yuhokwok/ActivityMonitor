import SwiftUI
import Combine

@main
struct ActivityMonitorApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var monitorStore = MonitorStore()
    @StateObject private var liveActivityController = LiveActivityController()

    var body: some Scene {
        WindowGroup {
            DashboardView(store: monitorStore, liveActivity: liveActivityController)
                .preferredColorScheme(.dark)
                .tint(.green)
                .onAppear {
                    monitorStore.start()
                    monitorStore.setSceneActive(scenePhase == .active)
                }
                .onChange(of: scenePhase) { _, phase in
                    monitorStore.setSceneActive(phase == .active)
                    if phase != .active, liveActivityController.isActive {
                        Task { await liveActivityController.pause(snapshot: monitorStore.snapshot) }
                    }
                }
                .onReceive(monitorStore.$snapshot.dropFirst()) { snapshot in
                    guard liveActivityController.isActive, scenePhase == .active else { return }
                    Task { await liveActivityController.update(snapshot: snapshot) }
                }
        }
    }
}
