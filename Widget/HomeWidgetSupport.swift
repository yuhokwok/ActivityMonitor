import SwiftUI
import WidgetKit

enum HomeWidgetFormat {
    static func battery(_ value: Double?) -> String { value.map { $0.formatted(.percent.precision(.fractionLength(0))) } ?? "—" }
    static func percent(_ value: Double?) -> String { value.map { $0.formatted(.percent.precision(.fractionLength(0))) } ?? "—" }
    static func storage(_ value: Int64?) -> String {
        guard let value, value >= 0 else { return "—" }
        return ByteCountFormatter.string(fromByteCount: value, countStyle: .memory)
    }
    static func memoryFraction(_ used: UInt64?, _ physical: UInt64?) -> Double? {
        guard let used, let physical, physical > 0, used <= physical else { return nil }
        return min(1, max(0, Double(used) / Double(physical)))
    }
    static func thermalKey(_ value: String) -> LocalizedStringKey {
        switch value {
        case "nominal": "widget.thermal.nominal"
        case "fair": "widget.thermal.fair"
        case "serious": "widget.thermal.serious"
        case "critical": "widget.thermal.critical"
        default: "widget.thermal.unknown"
        }
    }
    static func thermalColor(_ value: String) -> Color {
        switch value {
        case "nominal": HomeColor.green
        case "fair": HomeColor.memory
        case "serious": HomeColor.temperature
        case "critical": .red
        default: .white.opacity(0.34)
        }
    }
    static func thermalFraction(_ value: String) -> CGFloat? {
        switch value {
        case "nominal": 0.50
        case "fair": 0.70
        case "serious": 0.85
        case "critical": 1.0
        default: nil
        }
    }
}

enum HomeColor {
    static let green = Color(red: 0.02, green: 0.94, blue: 0.25)
    static let temperature = Color(red: 1, green: 0.48, blue: 0.16)
    static let storage = Color(red: 0.72, green: 0.36, blue: 1)
    static let memory = Color(red: 1, green: 0.82, blue: 0)
}

#Preview("Small default", as: .systemSmall) { MonitorHomeWidget() } timeline: {
    MonitorHomeEntry.preview()
}

#Preview("Medium default", as: .systemMedium) { MonitorHomeWidget() } timeline: {
    MonitorHomeEntry.preview()
}

#Preview("Small storage", as: .systemSmall) { MonitorHomeWidget() } timeline: {
    MonitorHomeEntry.preview(metrics: ["storage"])
}

#Preview("Medium battery and RAM", as: .systemMedium) { MonitorHomeWidget() } timeline: {
    MonitorHomeEntry.preview(metrics: ["battery", "memory"])
}

#Preview("Large RAM", as: .systemLarge) { MonitorHomeWidget() } timeline: {
    MonitorHomeEntry.preview(metrics: ["memory", "storage"])
}
