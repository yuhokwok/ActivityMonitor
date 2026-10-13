import SwiftUI
import WidgetKit

enum MetricScale: Equatable {
    case small, medium, large

    var isSmall: Bool { self == .small }
    var isLarge: Bool { self == .large }
    var titleSize: CGFloat { isSmall ? 9 : (isLarge ? 11 : 9) }
    var valueSize: CGFloat { isSmall ? 25 : (isLarge ? 34 : 21) }
}

struct MetricTile: View {
    let entry: MonitorHomeEntry
    let metric: String
    let scale: MetricScale

    var body: some View {
        VStack(alignment: .leading, spacing: scale.isSmall ? 5 : 8) {
            HomeSectionRule(title: title, color: color, fontSize: scale.titleSize)
            switch metric {
            case "temperature": temperatureTile
            case "storage": storageTile
            case "memory": memoryTile
            default: batteryTile
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var title: LocalizedStringKey {
        switch metric {
        case "temperature": "widget.thermal.title"
        case "storage": "widget.storage"
        case "memory": "widget.systemMemory"
        default: "widget.battery"
        }
    }

    private var color: Color {
        switch metric {
        case "temperature": HomeColor.temperature
        case "storage": HomeColor.storage
        case "memory": HomeColor.memory
        default: HomeColor.green
        }
    }

    private var batteryTile: some View {
        VStack(alignment: .leading, spacing: scale.isSmall ? 4 : 8) {
            HStack(spacing: scale.isSmall ? 8 : 11) {
                HomeBatteryTank(level: entry.batteryLevel)
                    .frame(width: scale.isSmall ? 28 : (scale.isLarge ? 42 : 32),
                           height: scale.isSmall ? 43 : (scale.isLarge ? 82 : 58))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: HomeWidgetFormat.battery(entry.batteryLevel))
                        .font(.system(size: scale.valueSize, weight: scale.isLarge ? .ultraLight : .light, design: .rounded))
                        .monospacedDigit().lineLimit(1).minimumScaleFactor(0.55)
                    HomeBatteryState(rawValue: entry.batteryState, fontSize: scale.isSmall ? 8 : 9)
                }
            }
            if scale.isLarge {
                Text("widget.battery").font(.system(size: 10, weight: .medium)).foregroundStyle(HomeColor.green)
            }
        }
    }

    private var temperatureTile: some View {
        VStack(alignment: scale.isSmall ? .leading : .center, spacing: scale.isSmall ? 5 : 8) {
            Text(HomeWidgetFormat.thermalKey(entry.thermalState))
                .font(.system(size: scale.valueSize * (scale.isSmall ? 0.62 : 0.78), weight: .light, design: .rounded))
                .foregroundStyle(HomeWidgetFormat.thermalColor(entry.thermalState))
                .lineLimit(2).minimumScaleFactor(0.58)
                .frame(maxWidth: .infinity, alignment: scale.isSmall ? .leading : .center)
            HomeThermalColumn(rawValue: entry.thermalState, compact: !scale.isLarge)
                .frame(width: scale.isLarge ? 62 : 34,
                       height: scale.isLarge ? 102 : (scale.isSmall ? 36 : 42))
                .accessibilityHidden(true)
            if scale.isLarge {
                Text("widget.thermal.title")
                    .font(.system(size: 10, weight: .medium)).foregroundStyle(HomeColor.temperature)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var storageTile: some View {
        VStack(alignment: .leading, spacing: scale.isSmall ? 3 : (scale.isLarge ? 7 : 4)) {
            Text(verbatim: HomeWidgetFormat.percent(entry.storageUsedFraction))
                .font(.system(size: scale.valueSize, weight: scale.isLarge ? .ultraLight : .light, design: .rounded))
                .monospacedDigit().lineLimit(1).minimumScaleFactor(0.55)
            HomeStorageDial(fraction: entry.storageUsedFraction, tint: HomeColor.storage)
                .frame(height: scale.isSmall ? 29 : (scale.isLarge ? 72 : 24))
                .accessibilityHidden(true)
            Text("widget.storageUsed").font(.system(size: scale.isSmall ? 8 : 10)).foregroundStyle(HomeColor.storage)
            if scale == .medium {
                Text(String(format: String(localized: "widget.availableValue"), HomeWidgetFormat.storage(entry.storageAvailableBytes)))
                    .font(.system(size: 7)).foregroundStyle(.white.opacity(0.55)).lineLimit(1).minimumScaleFactor(0.6)
                Text(String(format: String(localized: "widget.totalValue"), HomeWidgetFormat.storage(entry.storageTotalBytes)))
                    .font(.system(size: 7)).foregroundStyle(.white.opacity(0.55)).lineLimit(1).minimumScaleFactor(0.6)
            }
            if scale.isLarge {
                HomeCapacityValue(title: "widget.available", value: HomeWidgetFormat.storage(entry.storageAvailableBytes))
                HomeCapacityValue(title: "widget.total", value: HomeWidgetFormat.storage(entry.storageTotalBytes))
            }
        }
    }

    private var memoryTile: some View {
        VStack(alignment: .leading, spacing: scale.isSmall ? 4 : (scale.isLarge ? 8 : 4)) {
            Text(verbatim: HomeWidgetFormat.percent(HomeWidgetFormat.memoryFraction(entry.systemMemoryUsedBytes, entry.physicalMemoryBytes)))
                .font(.system(size: scale.valueSize, weight: scale.isLarge ? .ultraLight : .light, design: .rounded))
                .monospacedDigit().lineLimit(1).minimumScaleFactor(0.55)
            HomeMemoryGauge(fraction: HomeWidgetFormat.memoryFraction(entry.systemMemoryUsedBytes, entry.physicalMemoryBytes))
                .frame(height: scale.isSmall ? 29 : (scale.isLarge ? 72 : 24))
                .accessibilityHidden(true)
            Text(verbatim: HomeWidgetFormat.storage(entry.systemMemoryUsedBytes.map { Int64(clamping: $0) }))
                .font(.system(size: scale.isSmall ? 12 : (scale.isLarge ? 18 : 13), weight: .light, design: .rounded))
                .monospacedDigit().lineLimit(1).minimumScaleFactor(0.55)
            if scale.isLarge {
                Text(String(format: String(localized: "widget.memoryTotalValue"), HomeWidgetFormat.storage(entry.physicalMemoryBytes.map { Int64(clamping: $0) })))
                    .font(.system(size: 10)).foregroundStyle(.white.opacity(0.55)).lineLimit(1).minimumScaleFactor(0.7)
            }
            Text("widget.memoryEstimate")
                .font(.system(size: scale.isSmall ? 7 : 8)).foregroundStyle(HomeColor.memory.opacity(0.82))
                .lineLimit(2).minimumScaleFactor(0.65)
        }
    }
}
