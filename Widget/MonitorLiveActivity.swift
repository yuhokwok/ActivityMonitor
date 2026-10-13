import MonitorDomain
import MonitorActivity
import ActivityKit
import SwiftUI
import WidgetKit

struct MonitorLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MonitorAttributes.self) { context in
            LockScreenMonitor(state: context.state, isStale: context.isStale)
                .activityBackgroundTint(.black)
                .activitySystemActionForegroundColor(.white)
                .widgetURL(URL(string: "activitymonitor://dashboard"))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    IslandMetric(metric: context.state.resolvedDisplayedMetrics[0], state: context.state)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.resolvedDisplayedMetrics.count > 1 {
                        IslandMetric(metric: context.state.resolvedDisplayedMetrics[1], state: context.state)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        if context.state.resolvedDisplayedMetrics.count > 2 {
                            IslandMetric(metric: context.state.resolvedDisplayedMetrics[2], state: context.state)
                        }
                        SnapshotCaption(state: context.state, isStale: context.isStale)
                    }
                }
            } compactLeading: {
                Label(metricValue(context.state.resolvedDisplayedMetrics[0], state: context.state, compact: true),
                      systemImage: metricSymbol(context.state.resolvedDisplayedMetrics[0], state: context.state))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(metricColor(context.state.resolvedDisplayedMetrics[0]))
            } compactTrailing: {
                Text(verbatim: metricValue(.storage, state: context.state))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(Color.purple)
                    .accessibilityLabel(Text("widget.storage") + Text(": ") + Text(verbatim: metricValue(.storage, state: context.state)))
            } minimal: {
                Image(systemName: metricSymbol(context.state.resolvedDisplayedMetrics[0], state: context.state))
                    .foregroundStyle(metricColor(context.state.resolvedDisplayedMetrics[0]))
                    .accessibilityLabel(Text(metricTitle(context.state.resolvedDisplayedMetrics[0])))
            }
            .widgetURL(URL(string: "activitymonitor://dashboard"))
            .keylineTint(metricColor(context.state.resolvedDisplayedMetrics[0]))
        }
    }
}
