import MonitorDomain
import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: MonitorStore
    @ObservedObject var liveActivity: LiveActivityController
    @State private var shareURL: URL?
    @State private var exportError: String?
    @State private var showExportError = false
    @State private var showClearHistoryConfirmation = false
    @State private var showClearHistoryNotice = false

    var body: some View {
        List {
            Section("settings.sampling") {
                HStack {
                    Label(store.isSampling ? "settings.sampling_on" : "settings.sampling_off", systemImage: store.isSampling ? "waveform.path" : "pause.circle")
                    Spacer()
                    Circle().fill(store.isSampling ? Color.monitorGreen : .gray).frame(width: 8, height: 8)
                }
                .listRowBackground(Color.white.opacity(0.045))
                Button { store.refreshFromUser() } label: { Label("action.refresh", systemImage: "arrow.clockwise") }
                    .listRowBackground(Color.white.opacity(0.045))
                Text("settings.sampling_note").font(.system(size: 12)).foregroundStyle(Color.monitorMuted).listRowBackground(Color.white.opacity(0.045))
            }
            Section("nav.history") {
                Button(role: .destructive) { showClearHistoryConfirmation = true } label: { Label("settings.clear_history", systemImage: "trash") }
                    .listRowBackground(Color.white.opacity(0.045))
            }
            Section("settings.live_activity") {
                HStack {
                    Text("settings.live_status")
                    Spacer()
                    Text(liveActivity.isActive ? "live.active" : (liveActivity.isSupported ? "live.inactive" : "live.unsupported"))
                        .foregroundStyle(liveActivity.isActive ? Color.monitorGreen : Color.monitorMuted)
                }
                .listRowBackground(Color.white.opacity(0.045))
                Button {
                    Task {
                        if liveActivity.isActive { await liveActivity.end() }
                        else { await liveActivity.start(snapshot: store.snapshot) }
                    }
                } label: {
                    Label(liveActivity.isActive ? "live.stop" : "live.start", systemImage: liveActivity.isActive ? "stop.fill" : "play.fill")
                }
                .disabled(!liveActivity.isActive && !liveActivity.isSupported)
                .listRowBackground(Color.white.opacity(0.045))
                NavigationLink {
                    LiveMetricSelectionView(store: store, liveActivity: liveActivity)
                } label: {
                    Label("settings.live_data", systemImage: "slider.horizontal.3")
                }
                .listRowBackground(Color.white.opacity(0.045))
                if let error = liveActivity.errorMessage {
                    Text(error).font(.system(size: 12)).foregroundStyle(.red).listRowBackground(Color.white.opacity(0.045))
                }
            }
            Section("settings.widget_data") {
                Text("settings.widget_data_note").font(.system(size: 12)).foregroundStyle(Color.monitorMuted)
                    .listRowBackground(Color.white.opacity(0.045))
            }
            Section("settings.export") {
                Button { exportCSV() } label: { Label("settings.create_csv", systemImage: "tablecells") }
                    .listRowBackground(Color.white.opacity(0.045))
                if let shareURL {
                    ShareLink(item: shareURL, preview: SharePreview("settings.export_filename", image: Image(systemName: "tablecells"))) {
                        Label("settings.share_csv", systemImage: "square.and.arrow.up")
                    }
                    .listRowBackground(Color.white.opacity(0.045))
                }
                Text("settings.export_note").font(.system(size: 12)).foregroundStyle(Color.monitorMuted).listRowBackground(Color.white.opacity(0.045))
            }
            Section("settings.about") {
                HStack { Text("settings.version"); Spacer(); Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—").foregroundStyle(Color.monitorMuted) }
                    .listRowBackground(Color.white.opacity(0.045))
                Text("settings.language_note").font(.system(size: 12)).foregroundStyle(Color.monitorMuted).listRowBackground(Color.white.opacity(0.045))
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.black)
        .navigationTitle("nav.settings")
        .navigationBarTitleDisplayMode(.inline)
        .alert("settings.export_error", isPresented: $showExportError) { Button("common.ok", role: .cancel) { } } message: { Text(exportError ?? String(localized: "common.error")) }
        .confirmationDialog("settings.clear_history_confirm", isPresented: $showClearHistoryConfirmation, titleVisibility: .visible) {
            Button("settings.clear_history", role: .destructive) { store.clearHistory(); showClearHistoryNotice = true }
            Button("common.cancel", role: .cancel) { }
        }
        .alert("settings.clear_history_done", isPresented: $showClearHistoryNotice) { Button("common.ok", role: .cancel) { } }
    }

    private func exportCSV() {
        do { shareURL = try store.exportCSV() }
        catch { exportError = error.localizedDescription; showExportError = true }
    }
}

private struct LiveMetricSelectionView: View {
    @ObservedObject var store: MonitorStore
    @ObservedObject var liveActivity: LiveActivityController
    @AppStorage(MonitorDisplayPreferences.liveMetricKey) private var liveMetricsRaw = ""
    @State private var selectedMetrics = MonitorDisplayPreferences.readLiveMetrics()

    var body: some View {
        List {
            Section {
                ForEach(MonitorMetric.allCases) { metric in
                    metricRow(metric)
                }
            } footer: {
                Text("settings.live_data_note")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.black)
        .navigationTitle("settings.live_data")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            selectedMetrics = MonitorDisplayPreferences.readLiveMetrics()
        }
        .onChange(of: liveMetricsRaw) { _, _ in
            selectedMetrics = MonitorDisplayPreferences.readLiveMetrics()
        }
    }

    private func metricRow(_ metric: MonitorMetric) -> some View {
        let isSelected = selectedMetrics.contains(metric)
        let isLastSelected = isSelected && selectedMetrics.count == 1
        let isAtLimit = !isSelected && selectedMetrics.count >= 3

        return Button {
            toggle(metric)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.monitorGreen : Color.white.opacity(0.38))
                    .font(.system(size: 19))
                    .accessibilityHidden(true)
                Text(LocalizedStringKey("metric." + metric.rawValue))
                    .foregroundStyle(.white)
                Spacer()
                if let index = selectedMetrics.firstIndex(of: metric) {
                    Text("\(index + 1)").font(.caption.monospacedDigit())
                        .foregroundStyle(Color.monitorMuted)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isLastSelected || isAtLimit)
        .opacity(isLastSelected || isAtLimit ? 0.55 : 1)
        .accessibilityValue(Text(isSelected ? "common.on" : "common.off"))
        .listRowBackground(Color.white.opacity(0.045))
    }

    private func toggle(_ metric: MonitorMetric) {
        var next = selectedMetrics
        if let index = next.firstIndex(of: metric) {
            guard next.count > 1 else { return }
            next.remove(at: index)
        } else {
            guard next.count < 3 else { return }
            next.append(metric)
        }

        selectedMetrics = next
        MonitorDisplayPreferences.saveLiveMetrics(next)
        Task { await liveActivity.refreshDisplay(snapshot: store.snapshot) }
    }
}
