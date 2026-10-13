import MonitorTelemetry
import Foundation
import SwiftUI
import UIKit
import WidgetKit
import AppIntents

/// A point-in-time device sample, taken by the widget extension when WidgetKit grants it runtime.
/// No app CPU/memory/network rates: those would measure the extension, not the containing app.
struct MonitorHomeEntry: TimelineEntry {
    let date: Date
    let lastUpdated: Date
    let batteryLevel: Double?
    let batteryState: String
    let thermalState: String
    let storageTotalBytes: Int64?
    let storageAvailableBytes: Int64?
    let isPreview: Bool
    var displayedMetrics: [String] = ["battery", "temperature", "storage"]
    var systemMemoryUsedBytes: UInt64? = nil
    var physicalMemoryBytes: UInt64? = nil

    var staleAfter: Date { lastUpdated.addingTimeInterval(60 * 60) }
    /// The fallback entry is already marked stale even if WidgetKit renders its view in advance.
    var isStale: Bool { isStale(at: Date()) }

    func isStale(at now: Date) -> Bool {
        !isPreview && (date >= staleAfter || now >= staleAfter)
    }

    func staleEntry() -> MonitorHomeEntry {
        // Date schedules the presentation; lastUpdated continues to identify the original sample.
        MonitorHomeEntry(date: staleAfter, lastUpdated: lastUpdated,
                         batteryLevel: batteryLevel, batteryState: batteryState, thermalState: thermalState,
                         storageTotalBytes: storageTotalBytes, storageAvailableBytes: storageAvailableBytes,
                         isPreview: isPreview, displayedMetrics: displayedMetrics,
                         systemMemoryUsedBytes: systemMemoryUsedBytes, physicalMemoryBytes: physicalMemoryBytes)
    }

    var storageUsedBytes: Int64? {
        guard let total = storageTotalBytes, total >= 0,
              let available = storageAvailableBytes, available >= 0 else { return nil }
        return min(total, max(0, total - available))
    }

    var storageUsedFraction: Double? {
        guard let total = storageTotalBytes, total > 0, let used = storageUsedBytes else { return nil }
        return min(1, max(0, Double(used) / Double(total)))
    }

    /// Gallery/placeholder data only. Production timeline entries always come from a real sample.
    static func preview(metrics: [String]) -> MonitorHomeEntry {
        var entry = preview()
        entry.displayedMetrics = metrics
        return entry
    }

    static func preview(at date: Date = Date()) -> MonitorHomeEntry {
        MonitorHomeEntry(date: date, lastUpdated: date,
                         batteryLevel: 0.68, batteryState: "unplugged", thermalState: "nominal",
                         storageTotalBytes: 128_000_000_000, storageAvailableBytes: 48_000_000_000,
                         isPreview: true, displayedMetrics: ["battery", "temperature", "storage"],
                         systemMemoryUsedBytes: 5_200_000_000, physicalMemoryBytes: 8_000_000_000)
    }
}

struct MonitorHomeProvider: AppIntentTimelineProvider {
    typealias Intent = MonitorWidgetConfiguration
    static let requestedRefreshInterval: TimeInterval = 30 * 60

    func placeholder(in context: Context) -> MonitorHomeEntry {
        .preview()
    }

    func snapshot(for configuration: MonitorWidgetConfiguration, in context: Context) async -> MonitorHomeEntry {
        if context.isPreview {
            var entry = MonitorHomeEntry.preview()
            entry.displayedMetrics = configuration.displayedMetrics
            return entry
        }
        return await MonitorHomeSampler.sample(configuration: configuration)
    }

    func timeline(for configuration: MonitorWidgetConfiguration, in context: Context) async -> Timeline<MonitorHomeEntry> {
        let entry = await MonitorHomeSampler.sample(configuration: configuration)
        // This is the earliest requested reload, not a promise. WidgetKit controls its budget.
        // The fallback preserves the same sample and original timestamp while marking it stale.
        return Timeline(entries: [entry, entry.staleEntry()], policy: .after(entry.date.addingTimeInterval(Self.requestedRefreshInterval)))
    }
}

struct MonitorHomeWidget: Widget {
    static let kind = "MonitorHomeWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: Self.kind, intent: MonitorWidgetConfiguration.self, provider: MonitorHomeProvider()) { entry in
            HomeWidgetView(entry: entry)
                .widgetURL(URL(string: "activitymonitor://dashboard"))
        }
        .configurationDisplayName("widget.home.name")
        .description("widget.home.description")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

@MainActor
private enum MonitorHomeSampler {
    static func sample(configuration: MonitorWidgetConfiguration) -> MonitorHomeEntry {
        let device = UIDevice.current
        let previouslyEnabled = device.isBatteryMonitoringEnabled
        device.isBatteryMonitoringEnabled = true
        defer { device.isBatteryMonitoringEnabled = previouslyEnabled }

        let measuredLevel = device.batteryLevel
        let level: Double? = measuredLevel.isFinite && (0...1).contains(measuredLevel) ? Double(measuredLevel) : nil
        let batteryState: String
        switch device.batteryState {
        case .charging: batteryState = "charging"
        case .full: batteryState = "full"
        case .unplugged: batteryState = "unplugged"
        default: batteryState = "unknown"
        }

        let thermalState: String
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: thermalState = "nominal"
        case .fair: thermalState = "fair"
        case .serious: thermalState = "serious"
        case .critical: thermalState = "critical"
        @unknown default: thermalState = "unknown"
        }

        // This is capacity on the extension's storage volume, not a purgeable-capacity estimate.
        // Display-only disk-space values stay in this local timeline; no export or remote transfer.
        let values = try? URL(fileURLWithPath: NSHomeDirectory()).resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey])
        let total = values?.volumeTotalCapacity.flatMap { $0 >= 0 ? Int64($0) : nil }
        var available = values?.volumeAvailableCapacity.flatMap { $0 >= 0 ? Int64($0) : nil }
        if let total, let free = available { available = min(total, free) }
        let physicalMemoryBytes: UInt64? = {
            guard configuration.displayedMetrics.contains("memory") else { return nil }
            return ProcessInfo.processInfo.physicalMemory
        }()
        let memoryEstimate: SystemMemoryEstimate? = {
            guard let physicalMemoryBytes else { return nil }
            var sampler = SystemTelemetrySampler()
            return sampler.sample(physicalMemoryBytes: physicalMemoryBytes).memory
        }()
        let now = Date()
        return MonitorHomeEntry(date: now, lastUpdated: now,
                                batteryLevel: level, batteryState: batteryState, thermalState: thermalState,
                                storageTotalBytes: total, storageAvailableBytes: available, isPreview: false,
                                displayedMetrics: configuration.displayedMetrics,
                                systemMemoryUsedBytes: memoryEstimate?.usedBytes,
                                physicalMemoryBytes: physicalMemoryBytes)
    }
}
