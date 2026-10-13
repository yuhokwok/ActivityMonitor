import MonitorDomain
import MonitorActivity
import ActivityKit
import Foundation
import XCTest
@testable import ActivityMonitor

final class DisplayPreferencesTests: XCTestCase {
    private func withIsolatedDefaults(_ body: (UserDefaults) throws -> Void) throws {
        let name = "DisplayPreferencesTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        try body(defaults)
    }

    func testNormalizationPreservesOrderDropsUnknownsAndCapsTiles() {
        let metrics = MonitorDisplayPreferences.normalized(
            rawValues: ["futureMetric", "storage", "storage", "temperature", "memory", "cpu"],
            fallback: [.battery])
        XCTAssertEqual(metrics, [.storage, .temperature, .memory])
        XCTAssertEqual(MonitorDisplayPreferences.normalized(rawValues: ["network", "battery"],
                                                           fallback: [.cpu], limit: 1), [.network])
        XCTAssertEqual(MonitorDisplayPreferences.normalized(rawValues: MonitorMetric.allCases.map(\.rawValue),
                                                           fallback: [.cpu], limit: 99).count, 3)
    }

    func testMissingOrEmptySelectionAlwaysHasAValidFallback() {
        XCTAssertEqual(MonitorDisplayPreferences.normalized(rawValues: nil, fallback: [.memory, .memory, .cpu]), [.memory, .cpu])
        XCTAssertEqual(MonitorDisplayPreferences.normalized(rawValues: ["unknown"], fallback: [.temperature]), [.temperature])
        XCTAssertEqual(MonitorDisplayPreferences.normalized(rawValues: [], fallback: []), MonitorDisplayPreferences.defaultLiveMetrics)
        XCTAssertEqual(MonitorDisplayPreferences.normalized(rawValues: [], fallback: [], limit: 0), [.battery])
    }

    func testMalformedOrOldPreferenceRepresentationsReturnDefaults() throws {
        try withIsolatedDefaults { defaults in
            XCTAssertEqual(MonitorDisplayPreferences.readLiveMetrics(defaults: defaults), MonitorDisplayPreferences.defaultLiveMetrics)
            for raw in ["not-json", "{}", "[42]", "[]", "[\"futureMetric\"]"] {
                defaults.set(raw, forKey: MonitorDisplayPreferences.liveMetricKey)
                XCTAssertEqual(MonitorDisplayPreferences.readLiveMetrics(defaults: defaults), MonitorDisplayPreferences.defaultLiveMetrics)
            }
            defaults.set(["memory"], forKey: MonitorDisplayPreferences.liveMetricKey)
            XCTAssertEqual(MonitorDisplayPreferences.readLiveMetrics(defaults: defaults), MonitorDisplayPreferences.defaultLiveMetrics)
            defaults.set("[\"futureMetric\",\"storage\",\"storage\",\"memory\"]", forKey: MonitorDisplayPreferences.liveMetricKey)
            XCTAssertEqual(MonitorDisplayPreferences.readLiveMetrics(defaults: defaults), [.storage, .memory])
        }
    }

    func testSavingUsesJSONAndRetainsTheConfiguredOrder() throws {
        try withIsolatedDefaults { defaults in
            MonitorDisplayPreferences.saveLiveMetrics([.temperature, .storage, .temperature, .memory, .battery], defaults: defaults)
            let raw = try XCTUnwrap(defaults.string(forKey: MonitorDisplayPreferences.liveMetricKey))
            XCTAssertEqual(try JSONDecoder().decode([String].self, from: Data(raw.utf8)), ["temperature", "storage", "memory"])
            XCTAssertEqual(MonitorDisplayPreferences.readLiveMetrics(defaults: defaults), [.temperature, .storage, .memory])
            MonitorDisplayPreferences.saveLiveMetrics([], defaults: defaults)
            XCTAssertEqual(MonitorDisplayPreferences.readLiveMetrics(defaults: defaults), MonitorDisplayPreferences.defaultLiveMetrics)
        }
    }

    func testLegacyActivityUsesOriginalLayoutWithoutInventedStorageOrRAMCapacity() throws {
        let data = Data(#"{"timestamp":721692800,"isCharging":false,"samplingPaused":true}"#.utf8)
        let legacy = try JSONDecoder().decode(MonitorAttributes.ContentState.self, from: data)
        XCTAssertNil(legacy.displayedMetrics)
        XCTAssertEqual(legacy.resolvedDisplayedMetrics, [.battery, .cpu, .network])
        XCTAssertNil(legacy.physicalMemoryBytes)
        XCTAssertNil(legacy.storageUsedFraction)
        XCTAssertNil(legacy.storageUsedBytes)
        XCTAssertNil(legacy.storageAvailableBytes)
        XCTAssertNil(legacy.storageTotalBytes)
    }

    @MainActor
    func testConfiguredContentKeepsMetricScopesAndOriginalCaptureTime() throws {
        var sample = MonitorSnapshot(timestamp: Date(timeIntervalSince1970: 1_700_000_000))
        sample.appCPUPercent = 124
        sample.systemCPUPercent = 12
        sample.appMemoryBytes = 64_000_000
        sample.systemMemoryUsedBytes = 4_000_000_000
        sample.physicalMemoryBytes = 8_000_000_000
        sample.storageTotalBytes = 1_000
        sample.storageAvailableBytes = 250
        let content = LiveActivityController.makeContent(snapshot: sample, paused: true, metrics: [.memory, .storage, .temperature])
        let state = content.state
        XCTAssertEqual(state.resolvedDisplayedMetrics, [.memory, .storage, .temperature])
        XCTAssertEqual(state.systemCPUPercent, 12)
        XCTAssertEqual(state.appCPUPercent, 124)
        XCTAssertEqual(state.systemMemoryUsedBytes, 4_000_000_000)
        XCTAssertEqual(state.appMemoryBytes, 64_000_000)
        XCTAssertEqual(state.physicalMemoryBytes, 8_000_000_000)
        XCTAssertEqual(state.storageUsedFraction, 0.75)
        XCTAssertEqual(state.storageUsedBytes, 750)
        XCTAssertEqual(state.storageAvailableBytes, 250)
        XCTAssertEqual(state.storageTotalBytes, 1_000)
        XCTAssertEqual(state.timestamp, sample.timestamp)
        XCTAssertTrue(state.samplingPaused)
        XCTAssertLessThanOrEqual(try XCTUnwrap(content.staleDate), Date())
        let decoded = try JSONDecoder().decode(MonitorAttributes.ContentState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(decoded, state)
    }

    @MainActor
    func testDeselectingStorageKeepsPercentageButRemovesDiskByteFieldsFromPayload() throws {
        var sample = MonitorSnapshot()
        sample.storageTotalBytes = 1_000
        sample.storageAvailableBytes = 250
        let state = LiveActivityController.makeContent(snapshot: sample, paused: false, metrics: [.cpu, .network]).state
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
        XCTAssertEqual(state.storageUsedFraction, 0.75)
        XCTAssertNil(state.storageUsedBytes)
        XCTAssertNil(state.storageAvailableBytes)
        XCTAssertNil(state.storageTotalBytes)
        XCTAssertTrue(json.keys.contains("storageUsedFraction"))
        XCTAssertFalse(json.keys.contains("storageUsedBytes"))
        XCTAssertEqual(state.resolvedDisplayedMetrics, [.cpu, .network])
        XCTAssertNil(state.physicalMemoryBytes, "An unknown physical capacity must not become zero-sized RAM")
    }

    @MainActor
    func testSelectingSystemMetricsDoesNotFallBackToAppMetrics() {
        var sample = MonitorSnapshot()
        sample.appCPUPercent = 88
        sample.appMemoryBytes = 640_000_000
        let state = LiveActivityController.makeContent(snapshot: sample, paused: false, metrics: [.cpu, .memory]).state
        XCTAssertNil(state.systemCPUPercent)
        XCTAssertNil(state.systemMemoryUsedBytes)
        XCTAssertEqual(state.resolvedDisplayedMetrics, [.cpu, .memory])
    }
}
