import Darwin
import Foundation

/// HOST_CPU_LOAD_INFO exposes aggregate 32-bit tick counters across all processors.
struct SystemCPUTicks: Equatable {
    let user: UInt32
    let system: UInt32
    let idle: UInt32
    let nice: UInt32

    func usagePercent(since previous: SystemCPUTicks) -> Double? {
        let deltas = [user &- previous.user, system &- previous.system,
                      idle &- previous.idle, nice &- previous.nice]
        // Modular subtraction handles a normal UInt32 wrap. An ambiguous backward jump
        // or extremely long gap is discarded; lifecycle transitions also reset the baseline.
        guard deltas.allSatisfy({ $0 <= UInt32.max / 2 }) else { return nil }
        let total = deltas.reduce(UInt64(0)) { $0 + UInt64($1) }
        guard total > 0 else { return nil } // A cached/unchanged host sample is not 0% CPU.
        let busy = UInt64(deltas[0]) + UInt64(deltas[1]) + UInt64(deltas[3])
        return min(100, max(0, Double(busy) / Double(total) * 100))
    }
}

public struct SystemMemoryEstimate: Equatable {
    public let usedBytes: UInt64
    public let freeBytes: UInt64

    /// Physical RAM minus host free pages, which already include speculative pages.
    /// Includes inactive/file-backed cache, compressed memory and reserved/system usage;
    /// it is an occupancy estimate, not memory pressure or the sum of process footprints.
    static func make(physicalBytes: UInt64, freePages: UInt64, pageSize: UInt64) -> Self? {
        guard physicalBytes > 0, pageSize > 0 else { return nil }
        let free = freePages.multipliedReportingOverflow(by: pageSize)
        guard !free.overflow, free.partialValue <= physicalBytes else { return nil }
        return Self(usedBytes: physicalBytes - free.partialValue, freeBytes: free.partialValue)
    }
}

public struct SystemTelemetryReading {
    public let cpuPercent: Double?
    public let memory: SystemMemoryEstimate?

    init(cpuPercent: Double? = nil, memory: SystemMemoryEstimate? = nil) {
        self.cpuPercent = cpuPercent
        self.memory = memory
    }
}

/// Public Darwin host APIs only. Kernel policy may deny or cache statistics on some OS builds.
/// Failure is unavailable, never replaced with this app's CPU or memory usage.
/// On Simulator these APIs describe the simulator host, not a physical iPhone/iPad.
public struct SystemTelemetrySampler {
    private var previousCPU: SystemCPUTicks?

    public init() {}

    public mutating func reset() { previousCPU = nil }

    mutating func cpuPercent(for current: SystemCPUTicks?) -> Double? {
        defer { previousCPU = current }
        guard let current, let previousCPU else { return nil }
        return current.usagePercent(since: previousCPU)
    }

    public mutating func sample(physicalMemoryBytes: UInt64) -> SystemTelemetryReading {
        let host = mach_host_self()
        guard host != mach_port_t(MACH_PORT_NULL) else {
            reset()
            return SystemTelemetryReading()
        }
        // mach_host_self creates a send-right reference. Release it for every sample.
        defer { mach_port_deallocate(mach_task_self_, host) }
        return SystemTelemetryReading(cpuPercent: cpuPercent(for: Self.cpuTicks(host: host)),
                                      memory: Self.memory(host: host, physicalMemoryBytes: physicalMemoryBytes))
    }

    private static func cpuTicks(host: host_t) -> SystemCPUTicks? {
        var info = host_cpu_load_info_data_t()
        let requiredCount = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        var count = requiredCount
        let status = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(requiredCount)) {
                host_statistics(host, host_flavor_t(HOST_CPU_LOAD_INFO), $0, &count)
            }
        }
        guard status == KERN_SUCCESS, count >= requiredCount else { return nil }
        // CPU_STATE_USER = 0, SYSTEM = 1, IDLE = 2, NICE = 3 in the public SDK.
        return SystemCPUTicks(user: info.cpu_ticks.0, system: info.cpu_ticks.1,
                              idle: info.cpu_ticks.2, nice: info.cpu_ticks.3)
    }

    private static func memory(host: host_t, physicalMemoryBytes: UInt64) -> SystemMemoryEstimate? {
        var pageSize: vm_size_t = 0
        guard host_page_size(host, &pageSize) == KERN_SUCCESS, pageSize > 0 else { return nil }
        var info = vm_statistics64_data_t()
        let capacity = MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size
        var count = mach_msg_type_number_t(capacity)
        let status = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: capacity) {
                host_statistics64(host, host_flavor_t(HOST_VM_INFO64), $0, &count)
            }
        }
        // free_count is the first natural_t in every public vm_statistics64 revision.
        // Do not require the newest struct length: older OS kernels return an earlier revision.
        guard status == KERN_SUCCESS, count >= 1 else { return nil }
        // Apple XNU vm_statistics.h explicitly includes speculative_count in free_count:
        // https://github.com/apple-oss-distributions/xnu/blob/main/osfmk/mach/vm_statistics.h
        return .make(physicalBytes: physicalMemoryBytes, freePages: UInt64(info.free_count), pageSize: UInt64(pageSize))
    }
}
