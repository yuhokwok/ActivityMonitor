import MonitorDomain
import MonitorActivity
import ActivityKit
import XCTest
@testable import ActivityMonitor

final class MonitorCoreTests: XCTestCase {
    func testStorageDoesNotInventValuesWhenUnavailable() {
        var sample = MonitorSnapshot()
        XCTAssertNil(sample.storageUsedBytes)
        XCTAssertNil(sample.storageUsedFraction)
        sample.storageTotalBytes = 100
        XCTAssertNil(sample.storageUsedBytes)
        XCTAssertNil(sample.storageUsedFraction)
    }

    func testStorageFractionHandlesBoundaries() {
        var sample = MonitorSnapshot()
        sample.storageTotalBytes = 1_000
        sample.storageAvailableBytes = 250
        XCTAssertEqual(sample.storageUsedBytes, 750)
        XCTAssertEqual(sample.storageUsedFraction, 0.75)
        sample.storageAvailableBytes = 1_200
        XCTAssertEqual(sample.storageUsedBytes, 0)
        XCTAssertEqual(sample.storageUsedFraction, 0)
        sample.storageTotalBytes = 0
        XCTAssertNil(sample.storageUsedFraction)
    }

    @MainActor
    func testExportContainsObservedSamplesAndExcludesRestrictedDiskAndBootData() throws {
        let store = MonitorStore()
        store.refresh()
        let exported = try store.exportCSV()
        defer { try? FileManager.default.removeItem(at: exported) }
        let contents = try String(contentsOf: exported, encoding: .utf8)
        let lines = contents.split(separator: "\n")
        let headers = lines[0].split(separator: ",")
        XCTAssertEqual(lines.count, store.history.count + 1)
        XCTAssertTrue(headers.contains("app_cpu_percent_one_core_100"))
        XCTAssertTrue(headers.contains("app_memory_footprint_bytes"))
        XCTAssertTrue(headers.contains("system_cpu_percent_all_cores_100"))
        XCTAssertTrue(headers.contains("system_memory_used_estimate_bytes"))
        XCTAssertFalse(contents.contains("storage"))
        XCTAssertFalse(contents.contains("uptime"))
        XCTAssertFalse(contents.contains("boot"))
        for line in lines.dropFirst() {
            XCTAssertEqual(line.split(separator: ",", omittingEmptySubsequences: false).count, headers.count)
        }
        XCTAssertGreaterThan(store.history[0].physicalMemoryBytes, 0)
    }

    @MainActor
    func testStopAndResumeDoNotReportBackgroundAverageAsCurrentCPUOrNetworkRate() {
        let store = MonitorStore()
        store.start()
        store.refresh()
        store.stop()
        XCTAssertFalse(store.isSampling)
        store.start()
        XCTAssertTrue(store.isSampling)
        XCTAssertNil(store.snapshot.appCPUPercent)
        XCTAssertNil(store.snapshot.systemCPUPercent)
        XCTAssertNil(store.snapshot.networkReceivedBytesPerSecond)
        XCTAssertNil(store.snapshot.networkSentBytesPerSecond)
        store.stop()
    }

    @MainActor
    func testLiveContentPreservesScopeAndTimestampAndHasExpiry() throws {
        var sample = MonitorSnapshot(timestamp: Date(timeIntervalSince1970: 1_700_000_000))
        sample.batteryLevel = 0.64
        sample.batteryState = .charging
        sample.appCPUPercent = 124
        sample.systemCPUPercent = 42
        sample.systemMemoryUsedBytes = 4_000_000_000
        sample.appMemoryBytes = 64_000_000
        sample.networkReceivedBytesPerSecond = 120
        sample.networkSentBytesPerSecond = 30
        sample.storageTotalBytes = 999
        sample.thermalState = .serious
        let content = LiveActivityController.makeContent(snapshot: sample, paused: false, metrics: MonitorDisplayPreferences.defaultLiveMetrics)
        XCTAssertEqual(content.state.timestamp, sample.timestamp)
        XCTAssertEqual(content.state.appCPUPercent, 124, "100% is one core; multicore app use must not clamp to 100%")
        XCTAssertTrue(content.state.isCharging)
        XCTAssertEqual(content.state.thermalStateRawValue, "serious")
        XCTAssertFalse(content.state.samplingPaused)
        XCTAssertEqual(content.staleDate, sample.timestamp.addingTimeInterval(30))
        let payload = try XCTUnwrap(String(data: JSONEncoder().encode(content.state), encoding: .utf8))
        XCTAssertFalse(payload.contains("storage"))
        XCTAssertEqual(content.state.systemCPUPercent, 42)
        XCTAssertEqual(content.state.systemMemoryUsedBytes, 4_000_000_000)
        XCTAssertTrue(payload.contains("systemCPUPercent"))
        let paused = LiveActivityController.makeContent(snapshot: sample, paused: true, metrics: MonitorDisplayPreferences.defaultLiveMetrics)
        XCTAssertTrue(paused.state.samplingPaused)
        XCTAssertEqual(paused.state.timestamp, sample.timestamp, "Pausing must not masquerade as a new measurement")
        XCTAssertLessThanOrEqual(try XCTUnwrap(paused.staleDate), Date())
    }

    func testLegacyLiveContentDecodesWithoutThermalState() throws {
        // All previously required fields are present; older payloads have no thermal-state key.
        let legacy = Data(#"{"timestamp":721692800,"isCharging":false,"samplingPaused":true}"#.utf8)
        let state = try JSONDecoder().decode(MonitorAttributes.ContentState.self, from: legacy)
        XCTAssertNil(state.thermalStateRawValue)
        XCTAssertNil(state.batteryStateRawValue)
        XCTAssertNil(state.systemCPUPercent)
        XCTAssertNil(state.systemMemoryUsedBytes)
        XCTAssertTrue(state.samplingPaused)
        XCTAssertEqual(state.timestamp, Date(timeIntervalSinceReferenceDate: 721692800))
    }

    @MainActor
    func testLiveThermalStateRoundTripsAllSystemCategories() throws {
        for thermal in [ThermalStatus.nominal, .fair, .serious, .critical, .unknown] {
            var sample = MonitorSnapshot()
            sample.thermalState = thermal
            let state = LiveActivityController.makeContent(snapshot: sample, paused: false, metrics: MonitorDisplayPreferences.defaultLiveMetrics).state
            let decoded = try JSONDecoder().decode(MonitorAttributes.ContentState.self, from: JSONEncoder().encode(state))
            XCTAssertEqual(decoded.thermalStateRawValue, thermal.rawValue)
        }
    }


    func testStorageRejectsInvalidCapacitiesAndClampsInconsistentAvailability() {
        var sample = MonitorSnapshot()
        sample.storageTotalBytes = 1_000
        sample.storageAvailableBytes = -1
        XCTAssertNil(sample.storageUsedBytes)
        XCTAssertNil(sample.storageUsedFraction)
        sample.storageTotalBytes = -1
        sample.storageAvailableBytes = 100
        XCTAssertNil(sample.storageUsedBytes)
        XCTAssertNil(sample.storageUsedFraction)
        sample.storageTotalBytes = 1_000
        sample.storageAvailableBytes = 1_200
        XCTAssertEqual(sample.storageUsedBytes, 0)
        XCTAssertEqual(sample.storageUsedFraction, 0)
        sample.storageAvailableBytes = 0
        XCTAssertEqual(sample.storageUsedBytes, 1_000)
        XCTAssertEqual(sample.storageUsedFraction, 1)
    }

    @MainActor
    func testLiveBatteryStatePreservesFullChargingUnpluggedAndUnknown() throws {
        for battery in [BatteryStatus.charging, .full, .unplugged, .unknown] {
            var sample = MonitorSnapshot()
            sample.batteryState = battery
            sample.storageTotalBytes = 1_000
            sample.storageAvailableBytes = 250
            let state = LiveActivityController.makeContent(snapshot: sample, paused: false, metrics: MonitorDisplayPreferences.defaultLiveMetrics).state
            let data = try JSONEncoder().encode(state)
            let decoded = try JSONDecoder().decode(MonitorAttributes.ContentState.self, from: data)
            XCTAssertEqual(decoded.batteryStateRawValue, battery.rawValue)
            XCTAssertEqual(decoded.isCharging, battery == .charging || battery == .full, "Keep the previous payload's powered-state boolean compatible")
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            XCTAssertEqual(state.storageUsedFraction, 0.75)
            XCTAssertNil(state.storageUsedBytes)
            XCTAssertNil(state.storageAvailableBytes)
            XCTAssertNil(state.storageTotalBytes)
            XCTAssertTrue(json.keys.contains("storageUsedFraction"))
        }
    }

}
