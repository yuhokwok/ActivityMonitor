import AppIntents

enum WidgetMetric: String, AppEnum {
    case battery
    case temperature
    case storage
    case memory

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "widget.configuration.metric"

    static var caseDisplayRepresentations: [WidgetMetric: DisplayRepresentation] = [
        .battery: "widget.configuration.battery",
        .temperature: "widget.configuration.temperature",
        .storage: "widget.configuration.storage",
        .memory: "widget.configuration.memory"
    ]
}

enum OptionalWidgetMetric: String, AppEnum {
    case battery
    case temperature
    case storage
    case memory
    case none

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "widget.configuration.optionalMetric"

    static var caseDisplayRepresentations: [OptionalWidgetMetric: DisplayRepresentation] = [
        .battery: "widget.configuration.battery",
        .temperature: "widget.configuration.temperature",
        .storage: "widget.configuration.storage",
        .memory: "widget.configuration.memory",
        .none: "widget.configuration.none"
    ]
}

struct MonitorWidgetConfiguration: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "widget.configuration.title"
    static var description = IntentDescription("widget.configuration.description")

    @Parameter(title: "widget.configuration.first", default: .battery)
    var firstMetric: WidgetMetric

    @Parameter(title: "widget.configuration.second", default: .temperature)
    var secondMetric: OptionalWidgetMetric

    @Parameter(title: "widget.configuration.third", default: .storage)
    var thirdMetric: OptionalWidgetMetric

    /// Returns selected metrics in display order, dropping optional omissions and duplicates.
    var displayedMetrics: [String] {
        var seen = Set<String>()
        return [firstMetric.rawValue, secondMetric.rawValue, thirdMetric.rawValue].compactMap { rawValue in
            guard rawValue != OptionalWidgetMetric.none.rawValue,
                  seen.insert(rawValue).inserted else { return nil }
            return rawValue
        }
    }
}
