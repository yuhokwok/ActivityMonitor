import MonitorDomain
import SwiftUI


extension BatteryStatus {
    var localizedName: String {
        switch self {
        case .unknown: String(localized: "battery.unknown")
        case .unplugged: String(localized: "battery.unplugged")
        case .charging: String(localized: "battery.charging")
        case .full: String(localized: "battery.full")
        }
    }
}

extension ThermalStatus {
    var localizedName: String {
        switch self {
        case .nominal: String(localized: "thermal.nominal")
        case .fair: String(localized: "thermal.fair")
        case .serious: String(localized: "thermal.serious")
        case .critical: String(localized: "thermal.critical")
        case .unknown: String(localized: "thermal.unknown")
        }
    }
}

extension ConnectionKind {
    var localizedName: String {
        switch self {
        case .wifi: String(localized: "connection.wifi")
        case .cellular: String(localized: "connection.cellular")
        case .wired: String(localized: "connection.wired")
        case .other: String(localized: "connection.other")
        case .offline: String(localized: "connection.offline")
        case .unknown: String(localized: "connection.unknown")
        }
    }
}

extension Color {
    static let monitorGreen = Color(red: 0.02, green: 0.94, blue: 0.25)
    static let monitorYellow = Color(red: 1.0, green: 0.82, blue: 0.0)
    static let monitorCyan = Color(red: 0.0, green: 0.78, blue: 0.95)
    static let monitorTemperature = Color(red: 1.0, green: 0.43, blue: 0.20)
    static let monitorStorage = Color(red: 0.73, green: 0.43, blue: 1.0)
    static let monitorMuted = Color.white.opacity(0.56)
    static let monitorLine = Color.white.opacity(0.14)
}

struct SectionHeading: View {
    let title: LocalizedStringKey
    let tint: Color
    var body: some View {
        HStack(spacing: 12) {
            Text(title).font(.system(size: 19, weight: .medium, design: .rounded)).foregroundStyle(tint)
            HStack(spacing: 0) {
                Circle().fill(tint).frame(width: 3, height: 3)
                Rectangle().fill(tint.opacity(0.8)).frame(height: 1)
            }
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
    }
}

struct MetricValue: View {
    let value: String
    let label: LocalizedStringKey
    let tint: Color
    var body: some View {
        VStack(spacing: 5) {
            Text(value).font(.system(size: 25, weight: .light, design: .rounded)).monospacedDigit().foregroundStyle(.white)
                .lineLimit(1).minimumScaleFactor(0.65)
            Text(label).font(.system(size: 12, weight: .regular)).foregroundStyle(tint.opacity(0.86)).lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

func formattedBytes(_ bytes: Int64?) -> String {
    guard let bytes, bytes >= 0 else { return String(localized: "common.unavailable") }
    return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .memory)
}

func formattedBytes(_ bytes: UInt64?) -> String {
    guard let bytes, bytes <= UInt64(Int64.max) else { return String(localized: "common.unavailable") }
    return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .memory)
}

func formattedRate(_ bytesPerSecond: Double?) -> String {
    guard let bytesPerSecond, bytesPerSecond.isFinite, bytesPerSecond >= 0 else { return String(localized: "common.unavailable") }
    let formatter = ByteCountFormatter()
    formatter.countStyle = .memory
    formatter.allowedUnits = [.useKB, .useMB, .useGB]
    formatter.includesUnit = true
    formatter.isAdaptive = true
    return "\(formatter.string(fromByteCount: Int64(bytesPerSecond))) /s"
}

func percentString(_ fraction: Double?) -> String {
    guard let fraction, fraction.isFinite else { return String(localized: "common.unavailable") }
    return "\(Int((fraction.clamped(to: 0...1) * 100).rounded()))%"
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self { min(max(self, range.lowerBound), range.upperBound) }
}
