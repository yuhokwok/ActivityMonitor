import SwiftUI

struct DashboardView: View {
    @ObservedObject var store: MonitorStore
    @ObservedObject var liveActivity: LiveActivityController
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showingLiveError = false

    private let green = Color.monitorGreen
    private let yellow = Color.monitorYellow
    private let cyan = Color.monitorCyan

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 36) {
                    if MonitorStore.isDesignPreview {
                        Label("preview.design", systemImage: "wand.and.stars")
                            .font(.system(size: 11, weight: .medium)).foregroundStyle(.yellow)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if horizontalSizeClass == .regular {
                        HStack(alignment: .top, spacing: 30) {
                            VStack(spacing: 36) { batterySection; hardwareSection; temperatureSection }
                            VStack(spacing: 36) { storageSection; networkSection; activitySection }
                        }
                    } else {
                        batterySection
                        hardwareSection
                        temperatureSection
                        storageSection
                        networkSection
                        activitySection
                    }
                }
                .frame(maxWidth: 920)
                .padding(.horizontal, horizontalSizeClass == .regular ? 36 : 18)
                .padding(.top, 20)
                .padding(.bottom, 36)
                .frame(maxWidth: .infinity)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("app.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        NavigationLink(destination: DetailsView(store: store)) { Label("nav.details", systemImage: "info.circle") }
                        NavigationLink(destination: HistoryView(store: store)) { Label("nav.history", systemImage: "chart.xyaxis.line") }
                        NavigationLink(destination: SettingsView(store: store, liveActivity: liveActivity)) { Label("nav.settings", systemImage: "gearshape") }
                        Button { store.refreshFromUser() } label: { Label("action.refresh", systemImage: "arrow.clockwise") }
                    } label: {
                        Image(systemName: "ellipsis.circle").font(.system(size: 20)).foregroundStyle(.white)
                    }
                    .accessibilityLabel("nav.menu")
                }
            }
            .alert("live.error_title", isPresented: $showingLiveError) {
                Button("common.ok", role: .cancel) { }
            } message: { Text(liveActivity.errorMessage ?? String(localized: "common.error")) }
        }
        .task(id: liveActivity.errorMessage) {
            if liveActivity.errorMessage != nil { showingLiveError = true }
        }
    }

    private var batterySection: some View {
        VStack(alignment: .leading, spacing: 28) {
            SectionHeading(title: "section.battery", tint: green)
            ZStack(alignment: .bottom) {
                BatteryWaveField(level: store.snapshot.batteryLevel, reduceMotion: reduceMotion)
                    .frame(height: 108)
                    .mask(LinearGradient(colors: [.clear, .white.opacity(0.2), .white], startPoint: .top, endPoint: .bottom))
                HStack(alignment: .center, spacing: 20) {
                    BatterySequenceView(level: store.snapshot.batteryLevel, reduceMotion: reduceMotion)
                    VStack(alignment: .leading, spacing: 7) {
                        Text(percentString(store.snapshot.batteryLevel))
                            .font(.system(size: 49, weight: .ultraLight, design: .rounded)).monospacedDigit().foregroundStyle(.white)
                            .minimumScaleFactor(0.6).lineLimit(1)
                            .modifier(NumberJump(value: percentString(store.snapshot.batteryLevel)))
                        if store.snapshot.lowPowerMode {
                            Label("battery.low_power", systemImage: "leaf.fill").font(.system(size: 12, weight: .medium)).foregroundStyle(.yellow)
                        }
                    }
                    Spacer(minLength: 4)
                    VStack(alignment: .trailing, spacing: 10) {
                        Image(systemName: batteryStatusSymbol)
                            .font(.system(size: 21, weight: .light))
                            .foregroundStyle(green)
                            .accessibilityHidden(true)
                        Text(store.snapshot.batteryState.localizedName)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.trailing)
                            .lineLimit(2).minimumScaleFactor(0.8)
                        Text(store.snapshot.timestamp.formatted(date: .omitted, time: .shortened))
                            .font(.system(size: 10)).foregroundStyle(.white.opacity(0.65)).monospacedDigit()
                    }
                    .frame(maxWidth: 110, alignment: .trailing)
                    .accessibilityElement(children: .combine)
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 5)
            }
            .frame(height: 226)
            .overlay(alignment: .bottom) { Rectangle().fill(green.opacity(0.45)).frame(height: 1) }

        }
    }

    private var hardwareSection: some View {
        VStack(alignment: .leading, spacing: 28) {
            SectionHeading(title: "section.hardware", tint: yellow)
            HStack(alignment: .top, spacing: 36) {
                HalfGauge(value: store.snapshot.systemCPUPercent, maximum: 100, displayValue: store.snapshot.systemCPUPercent.map { String(format: "%.0f%%", $0) } ?? String(localized: "common.unavailable"), label: "hardware.system_cpu", tint: yellow)
                HalfGauge(value: systemMemoryFraction.map { $0 * 100 }, maximum: 100, displayValue: formattedBytes(store.snapshot.systemMemoryUsedBytes), label: "hardware.system_memory", tint: yellow)
            }
            Text("hardware.cpu_note")
                .font(.system(size: 11)).foregroundStyle(Color.monitorMuted)
            #if targetEnvironment(simulator)
            Text("hardware.simulator_note")
                .font(.system(size: 11)).foregroundStyle(Color.monitorMuted)
            #endif
        }
    }

    private var temperatureSection: some View {
        VStack(alignment: .leading, spacing: 28) {
            SectionHeading(title: "section.temperature", tint: .monitorTemperature)
            ThermometerGauge(state: store.snapshot.thermalState)
                .frame(width: 180)
                .frame(maxWidth: .infinity)
        }
    }

    private var storageSection: some View {
        VStack(alignment: .leading, spacing: 28) {
            SectionHeading(title: "section.storage", tint: .monitorStorage)
            VStack(spacing: 16) {
                HalfGauge(value: store.snapshot.storageUsedFraction.map { $0 * 100 }, maximum: 100,
                          displayValue: percentString(store.snapshot.storageUsedFraction),
                          label: "hardware.storage_used", tint: .monitorStorage, artworkHueRotation: 225)
                    .frame(width: 180)
                Text(String(format: String(localized: "hardware.storage_footer"),
                            formattedBytes(store.snapshot.storageAvailableBytes),
                            formattedBytes(store.snapshot.storageTotalBytes)))
                    .font(.system(size: 11)).foregroundStyle(Color.monitorMuted)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var networkSection: some View {
        VStack(alignment: .leading, spacing: 28) {
            SectionHeading(title: "section.network", tint: cyan)
            HStack(spacing: 36) {
                NetworkRing(primaryValue: formattedRate(store.snapshot.networkSentBytesPerSecond), secondaryValue: formattedRate(store.snapshot.networkReceivedBytesPerSecond), label: "network.transfer", tint: cyan, symbol: "arrow.up")
                NetworkRing(primaryValue: formattedBytes(totalNetworkBytes), secondaryValue: nil, label: "network.total", tint: cyan, symbol: nil)
            }
            HStack {
                Label(LocalizedStringKey(store.snapshot.connection.localizationKey), systemImage: connectionSymbol)
                    .lineLimit(1).minimumScaleFactor(0.7)
                Spacer()
                if store.snapshot.isExpensiveConnection { Text("network.expensive").foregroundStyle(.yellow) }
            }
            .font(.system(size: 12)).foregroundStyle(cyan.opacity(0.9))
        }
    }

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 13) {
            SectionHeading(title: "section.activity", tint: .white.opacity(0.75))
            HStack(spacing: 12) {
                Image(systemName: liveActivity.isActive ? "dot.radiowaves.left.and.right" : "waveform.path")
                    .font(.system(size: 20)).foregroundStyle(liveActivity.isActive ? green : .white.opacity(0.65))
                VStack(alignment: .leading, spacing: 4) {
                    Text(liveActivity.isActive ? "live.active" : "live.inactive").font(.system(size: 15, weight: .medium)).foregroundStyle(.white)
                    Text(liveActivity.isSupported ? "live.supported_note" : "live.unsupported_note")
                        .font(.system(size: 12)).foregroundStyle(Color.monitorMuted)
                }
                Spacer()
                Button {
                    Task {
                        if liveActivity.isActive { await liveActivity.end() }
                        else { await liveActivity.start(snapshot: store.snapshot) }
                    }
                } label: {
                    Text(liveActivity.isActive ? "live.stop" : "live.start")
                        .font(.system(size: 13, weight: .semibold)).padding(.horizontal, 14).padding(.vertical, 8)
                        .background(liveActivity.isActive ? Color.white.opacity(0.12) : green.opacity(0.18), in: Capsule())
                        .foregroundStyle(liveActivity.isActive ? .white : green)
                }
                .disabled(!liveActivity.isActive && !liveActivity.isSupported)
                .accessibilityHint("live.button_hint")
            }
            .padding(14).background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private var systemMemoryFraction: Double? {
        guard let used = store.snapshot.systemMemoryUsedBytes, store.snapshot.physicalMemoryBytes > 0 else { return nil }
        return min(1, Double(used) / Double(store.snapshot.physicalMemoryBytes))
    }
    private var totalNetworkBytes: UInt64? {
        guard let sent = store.snapshot.networkSentBytes, let received = store.snapshot.networkReceivedBytes else { return nil }
        let (sum, overflow) = sent.addingReportingOverflow(received)
        return overflow ? nil : sum
    }
    private var batteryStatusSymbol: String {
        switch store.snapshot.batteryState {
        case .unknown: "questionmark.circle"
        case .unplugged: "battery.100percent"
        case .charging: "bolt.fill"
        case .full: "checkmark.circle.fill"
        }
    }

    private var connectionSymbol: String {
        switch store.snapshot.connection {
        case .wifi: "wifi"
        case .cellular: "antenna.radiowaves.left.and.right"
        case .wired: "cable.connector"
        case .offline: "wifi.slash"
        case .other, .unknown: "network"
        }
    }
}
