import MonitorDomain
import MonitorActivity
import ActivityKit
import Combine
import Foundation
import UIKit

@MainActor
final class LiveActivityController: ObservableObject {
    @Published private(set) var isActive = false
    @Published private(set) var isSupported = ActivityAuthorizationInfo().areActivitiesEnabled
    @Published private(set) var errorMessage: String?

    private var activity: Activity<MonitorAttributes>?
    private var activityStateTask: Task<Void, Never>?
    private var authorizationTask: Task<Void, Never>?
    private var pendingUpdate: Task<Void, Never>?
    private var lastUpdate = Date.distantPast
    private var paused = false

    init() {
        rehydrate()
        authorizationTask = Task { [weak self] in
            for await enabled in ActivityAuthorizationInfo().activityEnablementUpdates {
                guard !Task.isCancelled else { return }
                self?.isSupported = enabled
            }
        }
    }

    deinit {
        activityStateTask?.cancel()
        authorizationTask?.cancel()
        pendingUpdate?.cancel()
    }

    func rehydrate() {
        isSupported = ActivityAuthorizationInfo().areActivitiesEnabled
        let existing = Activity<MonitorAttributes>.activities.first {
            $0.activityState == .active || $0.activityState == .stale
        }
        activity = existing
        isActive = existing != nil
        paused = existing?.content.state.samplingPaused ?? false
        observeState()
    }

    func start(snapshot: MonitorSnapshot) async {
        errorMessage = nil
        rehydrate()
        guard isSupported else {
            errorMessage = String(localized: "live.error.disabled")
            return
        }
        guard UIApplication.shared.applicationState == .active else {
            errorMessage = String(localized: "live.error.foreground")
            return
        }
        paused = false
        if activity != nil {
            lastUpdate = .distantPast
            await update(snapshot: snapshot)
            return
        }
        do {
            activity = try Activity.request(
                attributes: MonitorAttributes(name: "Activity Monitor"),
                content: Self.makeContent(snapshot: snapshot, paused: false),
                pushType: nil
            )
            isActive = true
            lastUpdate = Date()
            observeState()
        } catch {
            errorMessage = String(localized: "live.error.start") + " " + error.localizedDescription
            isActive = false
        }
    }

    func update(snapshot: MonitorSnapshot) async {
        guard let activity, activity.activityState == .active || activity.activityState == .stale else { return }
        // A foreground observer can call this for each sample; ActivityKit writes are throttled.
        // Live Activities do not grant continuous background execution.
        let resuming = paused
        guard resuming || Date().timeIntervalSince(lastUpdate) >= 10 else { return }
        guard UIApplication.shared.applicationState == .active else { return }
        paused = false
        lastUpdate = Date()
        await enqueue(Self.makeContent(snapshot: snapshot, paused: false), for: activity)
    }

    /// Apply a user configuration change immediately without restarting an existing activity.
    /// A paused snapshot remains paused; changing the layout is not a new measurement.
    func refreshDisplay(snapshot: MonitorSnapshot) async {
        guard UIApplication.shared.applicationState == .active else { return }
        if activity == nil || activity?.activityState == .ended || activity?.activityState == .dismissed {
            rehydrate()
        }
        guard let activity, activity.activityState == .active || activity.activityState == .stale else { return }
        lastUpdate = Date()
        await enqueue(Self.makeContent(snapshot: snapshot, paused: paused), for: activity)
    }

    func pause(snapshot: MonitorSnapshot) async {
        guard let activity else { return }
        paused = true
        // A short, finite task only completes this final write; it does not keep sampling alive.
        let backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "Pause monitor snapshot")
        await enqueue(Self.makeContent(snapshot: snapshot, paused: true), for: activity)
        if backgroundTask != .invalid { UIApplication.shared.endBackgroundTask(backgroundTask) }
    }

    func end() async {
        let activeActivities = Activity<MonitorAttributes>.activities
        activity = nil
        isActive = false
        paused = false
        activityStateTask?.cancel()
        await pendingUpdate?.value
        for item in activeActivities { await item.end(nil, dismissalPolicy: .immediate) }
    }

    private func enqueue(_ content: ActivityContent<MonitorAttributes.ContentState>, for activity: Activity<MonitorAttributes>) async {
        let previous = pendingUpdate
        let next = Task {
            await previous?.value
            guard !Task.isCancelled else { return }
            await activity.update(content)
        }
        pendingUpdate = next
        await next.value
    }

    static func makeContent(snapshot: MonitorSnapshot, paused: Bool, metrics: [MonitorMetric]? = nil) -> ActivityContent<MonitorAttributes.ContentState> {
        let selection = metrics.map {
            MonitorDisplayPreferences.normalized(rawValues: $0.map(\.rawValue),
                                                 fallback: MonitorDisplayPreferences.defaultLiveMetrics)
        } ?? MonitorDisplayPreferences.readLiveMetrics()
        return ActivityContent(
            state: .init(snapshot: snapshot, paused: paused, metrics: selection),
            // A killed/suspended app cannot refresh; the OS can mark an old sample as stale.
            staleDate: paused ? Date() : snapshot.timestamp.addingTimeInterval(30)
        )
    }

    private func observeState() {
        activityStateTask?.cancel()
        guard let observed = activity else { return }
        activityStateTask = Task { [weak self] in
            for await state in observed.activityStateUpdates {
                guard !Task.isCancelled else { return }
                guard let self, self.activity?.id == observed.id else { return }
                if state == .ended || state == .dismissed {
                    self.activity = nil
                    self.isActive = false
                    return
                }
            }
        }
    }
}
