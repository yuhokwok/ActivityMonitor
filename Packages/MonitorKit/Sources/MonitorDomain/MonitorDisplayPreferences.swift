import Foundation

/// Stable identifiers shared by Settings and the widget extension's display configuration.
public enum MonitorMetric: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case battery, cpu, memory, network, temperature, storage
    public var id: String { rawValue }
}

public enum MonitorDisplayPreferences {
    public static let liveMetricKey = "liveActivity.metrics.v1"
    public static let defaultLiveMetrics: [MonitorMetric] = [.battery, .cpu, .network]

    /// Keep the user's order, discard unknown/duplicate identifiers, and allow one to three tiles.
    /// Missing, invalid, or empty selections use a nonempty fallback instead of a blank activity.
    public static func normalized(rawValues: [String]?, fallback: [MonitorMetric], limit: Int = 3) -> [MonitorMetric] {
        let effectiveLimit = min(3, max(1, limit))
        func unique(_ values: [MonitorMetric]) -> [MonitorMetric] {
            var seen = Set<MonitorMetric>()
            return values.filter { seen.insert($0).inserted }
        }
        let valid = unique((rawValues ?? []).compactMap(MonitorMetric.init(rawValue:)))
        let defaultSelection = unique(fallback.isEmpty ? defaultLiveMetrics : fallback)
        return Array((valid.isEmpty ? defaultSelection : valid).prefix(effectiveLimit))
    }

    public static func readLiveMetrics(defaults: UserDefaults = .standard) -> [MonitorMetric] {
        let values: [String]?
        if let raw = defaults.string(forKey: liveMetricKey), let data = raw.data(using: .utf8) {
            values = try? JSONDecoder().decode([String].self, from: data)
        } else {
            values = nil
        }
        return normalized(rawValues: values, fallback: defaultLiveMetrics)
    }

    public static func saveLiveMetrics(_ metrics: [MonitorMetric], defaults: UserDefaults = .standard) {
        let values = normalized(rawValues: metrics.map(\.rawValue), fallback: defaultLiveMetrics).map(\.rawValue)
        guard let data = try? JSONEncoder().encode(values), let raw = String(data: data, encoding: .utf8) else { return }
        defaults.set(raw, forKey: liveMetricKey)
    }
}
