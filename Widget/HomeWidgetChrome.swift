import SwiftUI
import WidgetKit

struct HomeWidgetHeader: View {
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "waveform.path.ecg").foregroundStyle(HomeColor.green)
            Text("widget.title").font(.system(size: 10, weight: .semibold)).tracking(0.35)
                .lineLimit(1).minimumScaleFactor(0.8)
        }
    }
}

struct HomeWidgetTimestamp: View {
    let entry: MonitorHomeEntry
    let compact: Bool

    var body: some View {
        HStack(spacing: 4) {
            if entry.isStale { Text("widget.stale").foregroundStyle(.orange) }
            Text("widget.updated").foregroundStyle(.white.opacity(0.5))
            Text(entry.lastUpdated, style: .time).monospacedDigit().foregroundStyle(.white.opacity(0.8))
        }
        .font(.system(size: compact ? 8 : 11, design: compact ? .default : .rounded))
        .lineLimit(1).minimumScaleFactor(0.7)
    }
}

struct HomeWidgetFooter: View {
    let entry: MonitorHomeEntry
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 3) {
                if entry.isStale { Text("widget.stale").foregroundStyle(.orange) }
                Text("widget.asof")
                Text(entry.lastUpdated, style: .time).monospacedDigit()
            }
            .font(.system(size: compact ? 8 : 9)).foregroundStyle(.white.opacity(0.52))
            Text("widget.refreshHint").font(.system(size: 8)).foregroundStyle(.white.opacity(0.42))
        }
        .lineLimit(1).minimumScaleFactor(0.7)
    }
}

struct HomeSectionRule: View {
    let title: LocalizedStringKey
    let color: Color
    var fontSize: CGFloat = 10

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: fontSize)).lineLimit(1).minimumScaleFactor(0.65)
            Rectangle().fill(color).frame(height: 0.7)
        }
        .foregroundStyle(color)
    }
}
