import Foundation

public enum BatteryStatus: String, Codable, Sendable {
    case unknown, unplugged, charging, full
    public var localizationKey: String { "battery.\(rawValue)" }
}

public enum ThermalStatus: String, Codable, Sendable {
    case nominal, fair, serious, critical, unknown
    public var localizationKey: String { "thermal.\(rawValue)" }
}

public enum ConnectionKind: String, Codable, Sendable {
    case wifi, cellular, wired, other, offline, unknown
    public var localizationKey: String { "connection.\(rawValue)" }
}

/// A foreground sample. Nil means unavailable or no comparable previous sample.
/// System CPU is aggregate across all cores (0...100%). App CPU is separate (100% = one core).
public struct MonitorSnapshot: Identifiable, Codable, Sendable {
    public var id: Date { timestamp }
    public var timestamp = Date()
    public var batteryLevel: Double?
    public var batteryState: BatteryStatus = .unknown
    public var lowPowerMode = false
    public var thermalState: ThermalStatus = .unknown
    public var storageTotalBytes: Int64?
    public var storageAvailableBytes: Int64?
    public var physicalMemoryBytes: UInt64 = 0
    public var systemCPUPercent: Double?
    public var systemMemoryUsedBytes: UInt64?
    public var systemMemoryFreeBytes: UInt64?
    public var appMemoryBytes: UInt64?
    public var appCPUPercent: Double?
    public var networkReceivedBytesPerSecond: Double?
    public var networkSentBytesPerSecond: Double?
    public var networkReceivedBytes: UInt64?
    public var networkSentBytes: UInt64?
    public var connection: ConnectionKind = .unknown
    public var isExpensiveConnection = false
    public var isConstrainedConnection = false
    public var deviceModel = ""
    public var systemVersion = ""
    public var processorCount = 0

    public init(timestamp: Date = Date()) {
        self.timestamp = timestamp
    }

    public var systemMemoryUsedFraction: Double? {
        guard physicalMemoryBytes > 0, let used = systemMemoryUsedBytes, used <= physicalMemoryBytes else { return nil }
        return Double(used) / Double(physicalMemoryBytes)
    }

    public var storageUsedBytes: Int64? {
        guard let total = storageTotalBytes, total >= 0,
              let available = storageAvailableBytes, available >= 0 else { return nil }
        return min(total, max(0, total - available))
    }

    public var storageUsedFraction: Double? {
        guard let total = storageTotalBytes, total > 0, let used = storageUsedBytes else { return nil }
        return min(1, Double(used) / Double(total))
    }
}
