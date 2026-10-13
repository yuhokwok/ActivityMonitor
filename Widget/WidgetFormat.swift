import SwiftUI

enum WidgetFormat {
    static func batterySymbol(_ state: String?) -> String {
        switch state {
        case "charging": return "bolt.fill"
        case "full": return "checkmark.circle.fill"
        case "unplugged": return "battery.100percent"
        default: return "questionmark.circle"
        }
    }
    static func batteryStateKey(_ state: String?) -> LocalizedStringKey {
        switch state {
        case "charging": return "widget.battery.charging"
        case "full": return "widget.battery.full"
        case "unplugged": return "widget.battery.unplugged"
        default: return "widget.battery.unknown"
        }
    }
    static func battery(_ value: Double?) -> String {
        value.map { $0.formatted(.percent.precision(.fractionLength(0))) } ?? "—"
    }
    static func cpu(_ value: Double?) -> String {
        value.map { ($0 / 100).formatted(.percent.precision(.fractionLength(0))) } ?? "—"
    }
    static func bytes(_ value: UInt64?) -> String {
        value.map { ByteCountFormatter.string(fromByteCount: Int64(clamping: $0), countStyle: .memory) } ?? "—"
    }
    static func rate(_ value: Double?) -> String {
        guard let value, value.isFinite, value >= 0 else { return "—" }
        return ByteCountFormatter.string(fromByteCount: Int64(min(value, Double(Int64.max / 2))), countStyle: .decimal) + "/s"
    }
}

extension Color {
    static let monitorGreen = Color(red: 0.02, green: 0.94, blue: 0.25)
    static let monitorYellow = Color(red: 1, green: 0.82, blue: 0)
    static let monitorCyan = Color(red: 0, green: 0.78, blue: 0.95)
}
