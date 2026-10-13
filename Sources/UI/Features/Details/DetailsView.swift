import MonitorDomain
import SwiftUI

struct DetailsView: View {
    @ObservedObject var store: MonitorStore
    private var snapshot: MonitorSnapshot { store.snapshot }

    var body: some View {
        List {
            Section("details.battery") {
                DetailRow(title: "details.level", value: percentString(snapshot.batteryLevel))
                DetailRow(title: "details.state", value: snapshot.batteryState.localizedName)
                DetailRow(title: "details.low_power", value: snapshot.lowPowerMode ? String(localized: "common.on") : String(localized: "common.off"))
            }
            Section("details.hardware") {
                DetailRow(title: "details.system_cpu", value: snapshot.systemCPUPercent.map { String(format: "%.1f%%", $0) } ?? String(localized: "common.unavailable"))
                DetailRow(title: "details.system_memory", value: formattedBytes(snapshot.systemMemoryUsedBytes))
                Text("hardware.cpu_note").font(.system(size: 12)).foregroundStyle(Color.monitorMuted).listRowBackground(Color.white.opacity(0.045))
                #if targetEnvironment(simulator)
                Text("hardware.simulator_note").font(.system(size: 12)).foregroundStyle(Color.monitorMuted).listRowBackground(Color.white.opacity(0.045))
                #endif
                DetailRow(title: "details.app_cpu", value: snapshot.appCPUPercent.map { String(format: "%.1f%%", $0) } ?? String(localized: "common.unavailable"))
                DetailRow(title: "details.app_memory", value: formattedBytes(snapshot.appMemoryBytes))
                DetailRow(title: "details.physical_memory", value: formattedBytes(snapshot.physicalMemoryBytes))
                DetailRow(title: "details.thermal", value: snapshot.thermalState.localizedName)
                Text("thermal.scope").font(.system(size: 12)).foregroundStyle(Color.monitorMuted).listRowBackground(Color.white.opacity(0.045))
                DetailRow(title: "details.cores", value: snapshot.processorCount > 0 ? String(snapshot.processorCount) : String(localized: "common.unavailable"))
            }
            Section("details.storage") {
                DetailRow(title: "details.used", value: formattedBytes(snapshot.storageUsedBytes))
                DetailRow(title: "details.available", value: formattedBytes(snapshot.storageAvailableBytes))
                DetailRow(title: "details.total", value: formattedBytes(snapshot.storageTotalBytes))
            }
            Section("details.network") {
                DetailRow(title: "details.connection", value: snapshot.connection.localizedName)
                DetailRow(title: "details.received_rate", value: formattedRate(snapshot.networkReceivedBytesPerSecond))
                DetailRow(title: "details.sent_rate", value: formattedRate(snapshot.networkSentBytesPerSecond))
                DetailRow(title: "details.received_total", value: formattedBytes(snapshot.networkReceivedBytes))
                DetailRow(title: "details.sent_total", value: formattedBytes(snapshot.networkSentBytes))
                if snapshot.isExpensiveConnection { DetailRow(title: "details.expensive", value: String(localized: "common.yes")) }
                if snapshot.isConstrainedConnection { DetailRow(title: "details.constrained", value: String(localized: "common.yes")) }
            }
            Section("details.device") {
                DetailRow(title: "details.model", value: snapshot.deviceModel.isEmpty ? String(localized: "common.unavailable") : snapshot.deviceModel)
                DetailRow(title: "details.system", value: snapshot.systemVersion.isEmpty ? String(localized: "common.unavailable") : snapshot.systemVersion)
                DetailRow(title: "details.sample_time", value: snapshot.timestamp.formatted(date: .abbreviated, time: .standard))
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.black)
        .navigationTitle("nav.details")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct DetailRow: View {
    let title: LocalizedStringKey
    let value: String
    var body: some View {
        HStack(spacing: 20) {
            Text(title).foregroundStyle(.white.opacity(0.72))
            Spacer(minLength: 8)
            Text(value).foregroundStyle(.white).multilineTextAlignment(.trailing).textSelection(.enabled)
        }
        .font(.system(size: 14))
        .listRowBackground(Color.white.opacity(0.045))
    }
}
