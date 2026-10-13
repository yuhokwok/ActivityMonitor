import MonitorDomain
import MonitorActivity
import SwiftUI

struct LockScreenMonitor: View {
    let state: MonitorAttributes.ContentState
    let isStale: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: "waveform.path.ecg").foregroundStyle(Color.monitorGreen)
                Text("widget.title").font(.system(size: 11, weight: .semibold))
                Spacer(minLength: 4)
                SnapshotCaption(state: state, isStale: isStale)
            }
            HStack(alignment: .top, spacing: 12) {
                ForEach(state.resolvedDisplayedMetrics) { metric in
                    LiveMetricTile(metric: metric, state: state)
                        .frame(maxWidth: .infinity, alignment: .top)
                }
            }
        }
        .padding(12)
        .foregroundStyle(.white)
    }
}

func metricTitle(_ metric: MonitorMetric) -> LocalizedStringKey {
    switch metric {
    case .battery: "widget.battery"
    case .cpu: "widget.systemCPU"
    case .memory: "widget.systemMemory"
    case .network: "widget.network"
    case .temperature: "widget.thermal.title"
    case .storage: "widget.storage"
    }
}

func metricColor(_ metric: MonitorMetric) -> Color {
    switch metric {
    case .battery: .monitorGreen
    case .cpu, .memory: .monitorYellow
    case .network: .monitorCyan
    case .temperature: .orange
    case .storage: .purple
    }
}

func metricSymbol(_ metric: MonitorMetric, state: MonitorAttributes.ContentState) -> String {
    switch metric {
    case .battery: WidgetFormat.batterySymbol(state.batteryStateRawValue)
    case .cpu: "cpu"
    case .memory: "memorychip"
    case .network: "arrow.down"
    case .temperature: "thermometer.medium"
    case .storage: "internaldrive"
    }
}

func metricValue(_ metric: MonitorMetric, state: MonitorAttributes.ContentState, compact: Bool = false) -> String {
    switch metric {
    case .battery: WidgetFormat.battery(state.batteryLevel)
    case .cpu: WidgetFormat.cpu(state.systemCPUPercent)
    case .memory: WidgetFormat.bytes(state.systemMemoryUsedBytes)
    case .network: compact ? WidgetFormat.rate(state.receivedBytesPerSecond) : "↓ " + WidgetFormat.rate(state.receivedBytesPerSecond) + "  ↑ " + WidgetFormat.rate(state.sentBytesPerSecond)
    case .temperature: String(localized: thermalKey(state.thermalStateRawValue))
    case .storage: state.storageUsedFraction.map { $0.formatted(.percent.precision(.fractionLength(0))) } ?? "—"
    }
}

func thermalKey(_ raw: String?) -> String.LocalizationValue {
    switch raw {
    case "nominal": "widget.thermal.nominal"
    case "fair": "widget.thermal.fair"
    case "serious": "widget.thermal.serious"
    case "critical": "widget.thermal.critical"
    default: "widget.thermal.unknown"
    }
}

struct IslandMetric: View {
    let metric: MonitorMetric
    let state: MonitorAttributes.ContentState
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(metricTitle(metric)).font(.caption2).foregroundStyle(metricColor(metric))
            Text(verbatim: metricValue(metric, state: state))
                .font(.system(.title3, design: .rounded, weight: .light)).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.6)
            if metric == .battery { BatteryStateCaption(rawValue: state.batteryStateRawValue) }
            if metric == .memory {
                Text("widget.memoryEstimate").font(.system(size: 8)).foregroundStyle(.white.opacity(0.55))
            }
        }
        .foregroundStyle(.white)
        .accessibilityElement(children: .combine)
    }
}

struct LiveMetricTile: View {
    let metric: MonitorMetric
    let state: MonitorAttributes.ContentState
    private var memoryFraction: Double? {
        guard let used = state.systemMemoryUsedBytes, let total = state.physicalMemoryBytes,
              total > 0, used <= total else { return nil }
        return Double(used) / Double(total)
    }
    var body: some View {
        VStack(spacing: 6) {
            SectionRule(title: metricTitle(metric), color: metricColor(metric))
            if metric != .network {
                Text(verbatim: metricValue(metric, state: state))
                    .font(.system(size: metric == .memory || metric == .temperature ? 19 : 25, weight: .light, design: .rounded))
                    .monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
            }
            switch metric {
            case .battery:
                BatteryTank(level: state.batteryLevel).frame(width: 28, height: 48).accessibilityHidden(true)
                BatteryStateCaption(rawValue: state.batteryStateRawValue)
            case .cpu:
                HardwareDial(fraction: state.systemCPUPercent.map { $0 / 100 }).frame(height: 40).accessibilityHidden(true)
            case .memory:
                HardwareDial(fraction: memoryFraction).frame(height: 40).accessibilityHidden(true)
                Text("widget.memoryEstimate").font(.system(size: 8)).foregroundStyle(.white.opacity(0.55))
                    .lineLimit(2).minimumScaleFactor(0.7)
            case .network:
                NetworkDial(state: state).frame(width: 76, height: 76)
            case .temperature:
                LiveThermometer(rawValue: state.thermalStateRawValue).frame(width: 24, height: 54).accessibilityHidden(true)
            case .storage:
                HardwareDial(fraction: state.storageUsedFraction, color: .purple).frame(height: 40).accessibilityHidden(true)
                Text(verbatim: state.storageUsedBytes.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .memory) } ?? "—")
                    .font(.system(size: 9)).monospacedDigit().foregroundStyle(.white.opacity(0.65))
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct BatteryStateCaption: View {
    let rawValue: String?

    var body: some View {
        Label(WidgetFormat.batteryStateKey(rawValue), systemImage: WidgetFormat.batterySymbol(rawValue))
            .font(.system(size: 8))
            .foregroundStyle(["charging", "full", "unplugged"].contains(rawValue ?? "") ? Color.monitorGreen : .gray)
            .lineLimit(1)
            .minimumScaleFactor(0.65)
    }
}

/// ProcessInfo thermal pressure categories, never an inferred sensor temperature in degrees.
struct ThermalCaption: View {
    let rawValue: String?

    private var status: (key: LocalizedStringKey, symbol: String, color: Color) {
        switch rawValue {
        case "nominal": return ("widget.thermal.nominal", "thermometer.low", .monitorGreen)
        case "fair": return ("widget.thermal.fair", "thermometer.medium", .monitorYellow)
        case "serious": return ("widget.thermal.serious", "thermometer.high", .orange)
        case "critical": return ("widget.thermal.critical", "thermometer.high", .red)
        default: return ("widget.thermal.unknown", "questionmark.circle", .gray)
        }
    }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: status.symbol)
            Text(status.key)
        }
        .font(.system(size: 9))
        .foregroundStyle(status.color)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("widget.thermal.title") + Text(": ") + Text(status.key))
    }
}

struct SnapshotCaption: View {
    let state: MonitorAttributes.ContentState
    let isStale: Bool

    var body: some View {
        HStack(spacing: 4) {
            Text("widget.snapshot")
            Text(verbatim: metricValue(.storage, state: state))
                .foregroundStyle(.purple)
            Text(state.timestamp, style: .time)
        }
        .font(.system(size: 10))
        .foregroundStyle(.white.opacity(0.6))
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
}

struct SectionRule: View {
    let title: LocalizedStringKey
    let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 10)).lineLimit(1).minimumScaleFactor(0.75)
            Rectangle().frame(height: 0.5)
        }
        .foregroundStyle(color)
    }
}
