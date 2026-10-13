import MonitorDomain
import SwiftUI
import Charts

private enum HistoryMetric: String, CaseIterable, Identifiable {
    case battery, cpu, memory, network
    var id: String { rawValue }
    var label: LocalizedStringKey {
        let key = "history.metric.\(rawValue)"
        return LocalizedStringKey(key)
    }
    var color: Color {
        switch self { case .battery: .monitorGreen; case .cpu, .memory: .monitorYellow; case .network: .monitorCyan }
    }
    func value(_ sample: MonitorSnapshot) -> Double? {
        switch self {
        case .battery: sample.batteryLevel.map { $0 * 100 }
        case .cpu: sample.systemCPUPercent
        case .memory: sample.systemMemoryUsedBytes.map { Double($0) / 1_048_576 }
        case .network: sample.networkReceivedBytesPerSecond.map { $0 / 1_024 }
        }
    }
    var unit: LocalizedStringKey {
        switch self { case .battery, .cpu: "%"; case .memory: "history.unit.mb"; case .network: "history.unit.kb_s" }
    }
}

private struct HistoryPoint: Identifiable {
    let sample: MonitorSnapshot
    let value: Double
    var id: Date { sample.timestamp }
}

struct HistoryView: View {
    @ObservedObject var store: MonitorStore
    @State private var metric: HistoryMetric = .battery
    private var history: [MonitorSnapshot] { store.history }
    private var points: [HistoryPoint] {
        history.compactMap { sample in metric.value(sample).map { HistoryPoint(sample: sample, value: $0) } }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Picker("history.metric_picker", selection: $metric) {
                    ForEach(HistoryMetric.allCases) { item in Text(item.label).tag(item) }
                }
                .pickerStyle(.segmented)
                if points.count >= 2 {
                    Chart(points) { point in
                        AreaMark(x: .value(String(localized: "history.time"), point.sample.timestamp), y: .value(String(localized: "history.value"), point.value))
                            .foregroundStyle(LinearGradient(colors: [metric.color.opacity(0.33), metric.color.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                        LineMark(x: .value(String(localized: "history.time"), point.sample.timestamp), y: .value(String(localized: "history.value"), point.value))
                            .foregroundStyle(metric.color).lineStyle(StrokeStyle(lineWidth: 2))
                    }
                    .chartXAxis { AxisMarks(values: .automatic(desiredCount: 3)) { _ in AxisGridLine().foregroundStyle(.white.opacity(0.10)); AxisValueLabel(format: .dateTime.minute().second()).foregroundStyle(.white.opacity(0.65)) } }
                    .chartYAxis { AxisMarks(position: .leading) { _ in AxisGridLine().foregroundStyle(.white.opacity(0.10)); AxisValueLabel().foregroundStyle(.white.opacity(0.65)) } }
                    .frame(height: 250)
                    .padding(14)
                    .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 16))
                    Text("history.chart_note").font(.system(size: 12)).foregroundStyle(Color.monitorMuted)
                } else {
                    ContentUnavailableView("history.empty_title", systemImage: "chart.xyaxis.line", description: Text("history.empty_note"))
                        .frame(maxWidth: .infinity, minHeight: 260)
                }
                Text("history.recent_samples").font(.headline).foregroundStyle(.white)
                ForEach(history.sorted { $0.timestamp > $1.timestamp }) { sample in
                    HStack(spacing: 12) {
                        Circle().fill(metric.color).frame(width: 7, height: 7)
                        Text(sample.timestamp.formatted(date: .omitted, time: .standard)).monospacedDigit().foregroundStyle(Color.monitorMuted)
                        Spacer()
                        Text(historyFormattedValue(metric.value(sample), metric: metric))
                        .foregroundStyle(.white).monospacedDigit()
                    }
                    .font(.system(size: 13)).padding(.vertical, 5)
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(18).frame(maxWidth: 850).frame(maxWidth: .infinity)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("nav.history")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private func historyFormattedValue(_ value: Double?, metric: HistoryMetric) -> String {
    guard let value else { return String(localized: "common.unavailable") }
    return switch metric {
    case .battery, .cpu: String(format: String(localized: "history.format.percent"), value)
    case .memory: String(format: String(localized: "history.format.mb"), value)
    case .network: String(format: String(localized: "history.format.kb_s"), value)
    }
}
