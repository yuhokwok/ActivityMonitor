import MonitorDomain
import XCTest
@testable import MonitorTelemetry

final class SystemTelemetryTests: XCTestCase {
    private let zero = SystemCPUTicks(user: 0, system: 0, idle: 0, nice: 0)

    func testCPUUsesAllCoreTickDeltasAndIncludesNiceWork() throws {
        let previous = SystemCPUTicks(user: 500, system: 400, idle: 800, nice: 100)
        let current = SystemCPUTicks(user: 520, system: 415, idle: 860, nice: 105)
        XCTAssertEqual(try XCTUnwrap(current.usagePercent(since: previous)), 40, accuracy: 0.0001)
        XCTAssertEqual(SystemCPUTicks(user: 0, system: 0, idle: 100, nice: 0).usagePercent(since: zero), 0)
        XCTAssertEqual(SystemCPUTicks(user: 20, system: 30, idle: 0, nice: 50).usagePercent(since: zero), 100)
        XCTAssertNil(zero.usagePercent(since: zero), "Unchanged/cached counters must not masquerade as idle CPU")
    }

    func testCPUHandlesCounterWrapWithoutOverflowingAggregate() throws {
        let previous = SystemCPUTicks(user: UInt32.max - 2, system: 0, idle: 20, nice: 0)
        let current = SystemCPUTicks(user: 3, system: 0, idle: 26, nice: 0)
        XCTAssertEqual(try XCTUnwrap(current.usagePercent(since: previous)), 50, accuracy: 0.0001)
        let large = SystemCPUTicks(user: 2_000_000_000, system: 2_000_000_000, idle: 2_000_000_000, nice: 2_000_000_000)
        XCTAssertEqual(try XCTUnwrap(large.usagePercent(since: zero)), 75, accuracy: 0.0001)
    }

    func testCPUFailureResetAndDiscontinuityRequireFreshBaseline() {
        var sampler = SystemTelemetrySampler()
        XCTAssertNil(sampler.cpuPercent(for: zero))
        XCTAssertEqual(sampler.cpuPercent(for: SystemCPUTicks(user: 10, system: 0, idle: 10, nice: 0)), 50)
        XCTAssertNil(sampler.cpuPercent(for: nil), "A denied host API clears the baseline")
        XCTAssertNil(sampler.cpuPercent(for: zero), "Recovery must not bridge the missing sample")
        sampler.reset()
        XCTAssertNil(sampler.cpuPercent(for: zero), "Foreground resume starts a new interval")
        let old = SystemCPUTicks(user: 100, system: 100, idle: 100, nice: 100)
        let reset = SystemCPUTicks(user: 1, system: 1, idle: 1, nice: 1)
        XCTAssertNil(reset.usagePercent(since: old), "An ambiguous backward jump must not generate a spike")
    }

    func testRAMUsesFreeCountOnceAndAccountsForPhysicalPageSize() throws {
        // Darwin free_count already includes speculative pages. Never subtract them a second time.
        let estimate = try XCTUnwrap(SystemMemoryEstimate.make(physicalBytes: 100 * 16_384,
                                                               freePages: 25, pageSize: 16_384))
        XCTAssertEqual(estimate.freeBytes, 25 * 16_384)
        XCTAssertEqual(estimate.usedBytes, 75 * 16_384)
        XCTAssertEqual(estimate.freeBytes + estimate.usedBytes, 100 * 16_384)
        XCTAssertEqual(SystemMemoryEstimate.make(physicalBytes: 4096, freePages: 1, pageSize: 4096)?.usedBytes, 0)
        XCTAssertEqual(SystemMemoryEstimate.make(physicalBytes: 4096, freePages: 0, pageSize: 4096)?.usedBytes, 4096)
    }

    func testRAMRejectsUnavailableInconsistentAndOverflowingInputs() {
        XCTAssertNil(SystemMemoryEstimate.make(physicalBytes: 0, freePages: 0, pageSize: 4096))
        XCTAssertNil(SystemMemoryEstimate.make(physicalBytes: 4096, freePages: 1, pageSize: 0))
        XCTAssertNil(SystemMemoryEstimate.make(physicalBytes: 4096, freePages: 2, pageSize: 4096))
        XCTAssertNil(SystemMemoryEstimate.make(physicalBytes: UInt64.max, freePages: UInt64.max, pageSize: 16_384))
    }

    func testSnapshotNeverSubstitutesAppMemoryForMissingSystemRAM() {
        var snapshot = MonitorSnapshot()
        snapshot.physicalMemoryBytes = 1_000
        snapshot.appMemoryBytes = 100
        XCTAssertNil(snapshot.systemMemoryUsedFraction)
        snapshot.systemMemoryUsedBytes = 750
        XCTAssertEqual(snapshot.systemMemoryUsedFraction, 0.75)
        snapshot.systemMemoryUsedBytes = 1_001
        XCTAssertNil(snapshot.systemMemoryUsedFraction)
    }
}
