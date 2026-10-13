import SwiftUI
import WidgetKit

import SwiftUI
import WidgetKit

struct HomeWidgetView: View {
    let entry: MonitorHomeEntry
    @Environment(\.widgetFamily) private var family

    private var metrics: [String] {
        let available = Set(["battery", "temperature", "storage", "memory"])
        var seen = Set<String>()
        let selected = Array(entry.displayedMetrics.filter { available.contains($0) && seen.insert($0).inserted }.prefix(3))
        return selected.isEmpty ? ["battery"] : selected
    }

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                smallView
            case .systemLarge:
                largeView
            default:
                mediumView
            }
        }
        .padding(family == .systemSmall ? 10 : 16)
        .foregroundStyle(.white)
        .containerBackground(Color.black, for: .widget)
        .widgetURL(URL(string: "activitymonitor://dashboard"))
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HomeWidgetHeader()
            MetricTile(entry: entry, metric: metrics[0], scale: .small)
                .frame(maxHeight: .infinity)
            HomeWidgetFooter(entry: entry, compact: true)
        }
        .accessibilityElement(children: .contain)
    }

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                HomeWidgetHeader()
                Spacer(minLength: 4)
                HomeWidgetTimestamp(entry: entry, compact: true)
            }
            HStack(alignment: .top, spacing: 9) {
                ForEach(Array(metrics.enumerated()), id: \.offset) { _, metric in
                    MetricTile(entry: entry, metric: metric, scale: .medium)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            Text("widget.refreshHint")
                .font(.system(size: 8)).foregroundStyle(.white.opacity(0.42))
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .accessibilityElement(children: .contain)
    }

    private var largeView: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .firstTextBaseline) {
                HomeWidgetHeader()
                Spacer()
                HomeWidgetTimestamp(entry: entry, compact: false)
            }
            HStack(alignment: .top, spacing: 16) {
                ForEach(Array(metrics.enumerated()), id: \.offset) { _, metric in
                    MetricTile(entry: entry, metric: metric, scale: .large)
                        .frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading)
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
            Rectangle().fill(Color.white.opacity(0.12)).frame(height: 0.5)
            Text("widget.refreshHint")
                .font(.system(size: 9)).foregroundStyle(.white.opacity(0.48))
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .accessibilityElement(children: .contain)
    }
}
