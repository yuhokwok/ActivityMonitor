import MonitorDomain
import MonitorTelemetry
import Combine
import Darwin
import Foundation
import Network
import UIKit
import WidgetKit

@MainActor
final class MonitorStore: ObservableObject {
    @Published private(set) var snapshot = MonitorSnapshot()
    @Published private(set) var history: [MonitorSnapshot] = []
    @Published private(set) var isSampling = false

    /// Explicit simulator/design capture mode. Production builds never override measured values.
    static var isDesignPreview: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--design-preview")
        #else
        false
        #endif
    }

    let sampleInterval: TimeInterval = 2
    let historyLimit = 300
    private var timer: Timer?
    private let pathMonitor = NWPathMonitor()
    private var pathKind: ConnectionKind = .unknown
    private var pathIsExpensive = false
    private var pathIsConstrained = false
    private var systemSampler = SystemTelemetrySampler()
    private var previousCPU: (time: TimeInterval, seconds: Double)?
    private var previousNetwork: (time: TimeInterval, counters: [String: InterfaceCounters])?
    private var lastStorageRead = Date.distantPast
    private var storageTotal: Int64?
    private var storageAvailable: Int64?

    init() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        pathMonitor.pathUpdateHandler = { [weak self] path in
            let kind: ConnectionKind
            if path.status != .satisfied { kind = .offline }
            else if path.usesInterfaceType(.wifi) { kind = .wifi }
            else if path.usesInterfaceType(.cellular) { kind = .cellular }
            else if path.usesInterfaceType(.wiredEthernet) { kind = .wired }
            else { kind = .other }
            let expensive = path.isExpensive
            let constrained = path.isConstrained
            Task { @MainActor [weak self] in
                self?.pathKind = kind
                self?.pathIsExpensive = expensive
                self?.pathIsConstrained = constrained
            }
        }
        pathMonitor.start(queue: DispatchQueue(label: "monitor.network-path"))
        refresh()
    }

    deinit {
        timer?.invalidate()
        pathMonitor.cancel()
    }

    func start() {
        guard !isSampling else { return }
        isSampling = true
        previousCPU = nil
        systemSampler.reset()
        previousNetwork = nil
        lastStorageRead = .distantPast
        refresh()
        if !Self.isDesignPreview { WidgetCenter.shared.reloadTimelines(ofKind: "MonitorHomeWidget") }
        timer = Timer.scheduledTimer(withTimeInterval: sampleInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }
        timer?.tolerance = 0.3
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        isSampling = false
        previousCPU = nil
        systemSampler.reset()
        previousNetwork = nil
    }

    func setSceneActive(_ active: Bool) {
        if active { start() } else { stop() }
    }

    func refresh() {
        let device = UIDevice.current
        let process = ProcessInfo.processInfo
        let now = Date()
        // Monotonic elapsed time prevents clock corrections from corrupting rates.
        let uptime = process.systemUptime
        var next = MonitorSnapshot(timestamp: now)
        let batteryLevel = device.batteryLevel
        next.batteryLevel = batteryLevel.isFinite && (0...1).contains(batteryLevel) ? Double(batteryLevel) : nil
        switch device.batteryState {
        case .charging: next.batteryState = .charging
        case .full: next.batteryState = .full
        case .unplugged: next.batteryState = .unplugged
        default: next.batteryState = .unknown
        }
        #if DEBUG
        if Self.isDesignPreview {
            let arguments = process.arguments
            let value: Double
            if let index = arguments.firstIndex(of: "--battery-level"), arguments.indices.contains(index + 1),
               let supplied = Double(arguments[index + 1]), supplied.isFinite, (0...1).contains(supplied) {
                value = supplied
            } else { value = 0.68 }
            next.batteryLevel = value
            next.batteryState = .unplugged
            if let index = arguments.firstIndex(of: "--battery-state"), arguments.indices.contains(index + 1),
               let state = BatteryStatus(rawValue: arguments[index + 1]) {
                next.batteryState = state
                if state == .full { next.batteryLevel = 1 }
                if state == .unknown { next.batteryLevel = nil }
            }
        }
        #endif
        next.lowPowerMode = process.isLowPowerModeEnabled
        switch process.thermalState {
        case .nominal: next.thermalState = .nominal
        case .fair: next.thermalState = .fair
        case .serious: next.thermalState = .serious
        case .critical: next.thermalState = .critical
        @unknown default: next.thermalState = .unknown
        }
        #if DEBUG
        if Self.isDesignPreview {
            let arguments = process.arguments
            if let index = arguments.firstIndex(of: "--thermal-state"), arguments.indices.contains(index + 1),
               let state = ThermalStatus(rawValue: arguments[index + 1]) {
                next.thermalState = state
            }
        }
        #endif
        if now.timeIntervalSince(lastStorageRead) >= 30 {
            readStorage()
            lastStorageRead = now
        }
        next.storageTotalBytes = storageTotal
        next.storageAvailableBytes = storageAvailable
        next.physicalMemoryBytes = process.physicalMemory
        let system = systemSampler.sample(physicalMemoryBytes: next.physicalMemoryBytes)
        next.systemCPUPercent = system.cpuPercent
        next.systemMemoryUsedBytes = system.memory?.usedBytes
        next.systemMemoryFreeBytes = system.memory?.freeBytes
        next.appMemoryBytes = Self.processMemoryFootprint()
        if let cpu = Self.processCPUSeconds() {
            if let previous = previousCPU, uptime > previous.time, cpu >= previous.seconds {
                next.appCPUPercent = max(0, (cpu - previous.seconds) / (uptime - previous.time) * 100)
            }
            previousCPU = (uptime, cpu)
        } else { previousCPU = nil }
        if let counters = Self.interfaceCounters() {
            next.networkReceivedBytes = counters.values.reduce(0) { $0 + $1.received }
            next.networkSentBytes = counters.values.reduce(0) { $0 + $1.sent }
            if let previous = previousNetwork, uptime > previous.time,
               Set(previous.counters.keys) == Set(counters.keys), !counters.isEmpty {
                var received: UInt64 = 0
                var sent: UInt64 = 0
                var comparable = true
                for (name, value) in counters {
                    guard let old = previous.counters[name], value.received >= old.received, value.sent >= old.sent else {
                        // Interface resets and legacy 32-bit counter wraps need a new baseline.
                        comparable = false
                        break
                    }
                    received += value.received - old.received
                    sent += value.sent - old.sent
                }
                if comparable {
                    next.networkReceivedBytesPerSecond = Double(received) / (uptime - previous.time)
                    next.networkSentBytesPerSecond = Double(sent) / (uptime - previous.time)
                }
            }
            previousNetwork = (uptime, counters)
        } else { previousNetwork = nil }
        next.connection = pathKind
        next.isExpensiveConnection = pathIsExpensive
        next.isConstrainedConnection = pathIsConstrained
        next.deviceModel = device.model
        next.systemVersion = "\(device.systemName) \(device.systemVersion)"
        next.processorCount = process.processorCount
        snapshot = next
        history.append(next)
        if history.count > historyLimit { history.removeFirst(history.count - historyLimit) }
    }

    /// User-requested refresh also asks WidgetKit to capture a fresh device snapshot.
    func refreshFromUser() {
        lastStorageRead = .distantPast
        refresh()
        if !Self.isDesignPreview { WidgetCenter.shared.reloadTimelines(ofKind: "MonitorHomeWidget") }
    }

    func clearHistory() {
        history = [snapshot]
    }

    func exportCSV() throws -> URL {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let header = "timestamp,battery_fraction,battery_state,low_power,thermal,device_physical_memory_bytes,system_cpu_percent_all_cores_100,system_memory_used_estimate_bytes,system_memory_free_bytes,app_memory_footprint_bytes,app_cpu_percent_one_core_100,interface_receive_bytes_per_second,interface_send_bytes_per_second,interface_receive_counter_bytes,interface_send_counter_bytes,connection"
        func value<T>(_ item: T?) -> String { item.map { String(describing: $0) } ?? "" }
        let rows = history.map { sample in
            [formatter.string(from: sample.timestamp), value(sample.batteryLevel), sample.batteryState.rawValue,
             String(sample.lowPowerMode), sample.thermalState.rawValue, String(sample.physicalMemoryBytes),
             value(sample.systemCPUPercent), value(sample.systemMemoryUsedBytes), value(sample.systemMemoryFreeBytes), value(sample.appMemoryBytes),
             value(sample.appCPUPercent), value(sample.networkReceivedBytesPerSecond), value(sample.networkSentBytesPerSecond),
             value(sample.networkReceivedBytes), value(sample.networkSentBytes), sample.connection.rawValue].joined(separator: ",")
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Activity-Monitor-\(UUID().uuidString).csv")
        try ([header] + rows).joined(separator: "\n").appending("\n").write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func readStorage() {
        do {
            let url = URL(fileURLWithPath: NSHomeDirectory())
            let values = try url.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey])
            // Invalid capacities are unavailable; free capacity cannot exceed this volume's total.
            storageTotal = values.volumeTotalCapacity.flatMap { $0 >= 0 ? Int64($0) : nil }
            storageAvailable = values.volumeAvailableCapacity.flatMap { $0 >= 0 ? Int64($0) : nil }
            if let total = storageTotal, let available = storageAvailable {
                storageAvailable = min(total, available)
            }
        } catch {
            storageTotal = nil
            storageAvailable = nil
        }
    }

    private static func processCPUSeconds() -> Double? {
        var usage = rusage()
        guard getrusage(RUSAGE_SELF, &usage) == 0 else { return nil }
        return Double(usage.ru_utime.tv_sec + usage.ru_stime.tv_sec)
            + Double(usage.ru_utime.tv_usec + usage.ru_stime.tv_usec) / 1_000_000
    }

    private static func processMemoryFootprint() -> UInt64? {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        return info.phys_footprint
    }

    private struct InterfaceCounters {
        let received: UInt64
        let sent: UInt64
    }

    /// Counters belong to device network interfaces, not this process or an internet speed test.
    /// Exclude loopback, tunnels, and peer-to-peer interfaces to avoid counting them twice.
    private static func interfaceCounters() -> [String: InterfaceCounters]? {
        var addresses: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addresses) == 0, let first = addresses else { return nil }
        defer { freeifaddrs(first) }
        var result: [String: InterfaceCounters] = [:]
        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let item = cursor {
            defer { cursor = item.pointee.ifa_next }
            let entry = item.pointee
            guard let address = entry.ifa_addr, Int32(address.pointee.sa_family) == AF_LINK,
                  let namePointer = entry.ifa_name, let data = entry.ifa_data else { continue }
            let name = String(cString: namePointer)
            guard name.hasPrefix("en") || name.hasPrefix("pdp_ip") else { continue }
            let counters = data.assumingMemoryBound(to: if_data.self).pointee
            result[name] = InterfaceCounters(received: UInt64(counters.ifi_ibytes), sent: UInt64(counters.ifi_obytes))
        }
        return result.isEmpty ? nil : result
    }
}
