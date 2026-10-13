import ActivityKit
import Foundation
import MonitorDomain

public struct MonitorAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public private(set) var timestamp: Date
        public private(set) var batteryLevel: Double?
        public private(set) var isCharging: Bool
        public private(set) var appCPUPercent: Double?
        public private(set) var appMemoryBytes: UInt64?
        public private(set) var receivedBytesPerSecond: Double?
        public private(set) var sentBytesPerSecond: Double?
        public private(set) var samplingPaused: Bool
        /// Optional so Live Activities created before thermal-state support still decode.
        public private(set) var thermalStateRawValue: String? = nil
        /// Nil for pre-upgrade payloads; the legacy isCharging bit remains for older consumers.
        public private(set) var batteryStateRawValue: String? = nil
        /// Separate system scope; older payloads stay unavailable rather than using app values.
        public private(set) var systemCPUPercent: Double? = nil
        public private(set) var systemMemoryUsedBytes: UInt64? = nil
        /// Older activities use the original battery / CPU / network layout.
        public private(set) var displayedMetrics: [String]? = nil
        public private(set) var physicalMemoryBytes: UInt64? = nil
        /// Storage fraction is always displayed; detailed bytes require the storage tile.
        public private(set) var storageUsedFraction: Double? = nil
        public private(set) var storageUsedBytes: Int64? = nil
        public private(set) var storageAvailableBytes: Int64? = nil
        public private(set) var storageTotalBytes: Int64? = nil

        /// Build the shared payload without changing the original sample time or metric scope.
        public init(snapshot: MonitorSnapshot, paused: Bool, metrics: [MonitorMetric]) {
            let selection = MonitorDisplayPreferences.normalized(
                rawValues: metrics.map(\.rawValue),
                fallback: MonitorDisplayPreferences.defaultLiveMetrics)
            let includesStorage = selection.contains(.storage)
            timestamp = snapshot.timestamp
            batteryLevel = snapshot.batteryLevel
            isCharging = snapshot.batteryState == .charging || snapshot.batteryState == .full
            appCPUPercent = snapshot.appCPUPercent
            appMemoryBytes = snapshot.appMemoryBytes
            receivedBytesPerSecond = snapshot.networkReceivedBytesPerSecond
            sentBytesPerSecond = snapshot.networkSentBytesPerSecond
            samplingPaused = paused
            thermalStateRawValue = snapshot.thermalState.rawValue
            batteryStateRawValue = snapshot.batteryState.rawValue
            systemCPUPercent = snapshot.systemCPUPercent
            systemMemoryUsedBytes = snapshot.systemMemoryUsedBytes
            displayedMetrics = selection.map(\.rawValue)
            physicalMemoryBytes = snapshot.physicalMemoryBytes > 0 ? snapshot.physicalMemoryBytes : nil
            storageUsedFraction = snapshot.storageUsedFraction
            storageUsedBytes = includesStorage ? snapshot.storageUsedBytes : nil
            storageAvailableBytes = includesStorage ? snapshot.storageAvailableBytes : nil
            storageTotalBytes = includesStorage ? snapshot.storageTotalBytes : nil
        }

        public var resolvedDisplayedMetrics: [MonitorMetric] {
            MonitorDisplayPreferences.normalized(rawValues: displayedMetrics,
                                                 fallback: MonitorDisplayPreferences.defaultLiveMetrics)
        }
    }

    public let name: String

    public init(name: String) {
        self.name = name
    }
}
