import SwiftUI
import SwiftData
import WidgetKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var samples: [StressSample]
    @State private var appState = MochiAppState.shared
    @State private var showBreath = false
    @State private var checkInToast: String?

    init() {
        let twentyFourHoursAgo = Calendar.current.date(byAdding: .hour, value: -24, to: Date()) ?? Date()
        _samples = Query(
            filter: #Predicate<StressSample> { $0.date >= twentyFourHoursAgo },
            sort: \.date,
            order: .reverse
        )
    }

    var body: some View {
        TabView {
            NavigationStack {
                DashboardView(
                    onBreathe: { showBreath = true },
                    onCheckIn: logCalmCheckIn
                )
            }
            .tabItem { Label("Today", systemImage: "sun.max") }

            NavigationStack {
                HistoryView(samples: samples)
            }
            .tabItem { Label("History", systemImage: "chart.xyaxis.line") }

            NavigationStack {
                IOSSettingsView()
            }
            .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tint(.calm)
        .sheet(isPresented: $showBreath) {
            BreathSessionView()
        }
        .task {
            // Drain a breath request that arrived before `.onChange` attached
            // (e.g. a cold launch from the "Start a breath session" intent).
            if appState.pendingBreathRequest {
                showBreath = true
                appState.consumeBreathRequest()
            }
        }
        .onChange(of: appState.pendingBreathRequest) { _, pending in
            if pending {
                showBreath = true
                appState.consumeBreathRequest()
            }
        }
        .overlay(alignment: .bottom) {
            if let toast = checkInToast {
                Text(toast)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 60)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private func logCalmCheckIn() {
        // Insert through the live environment context so @Query-backed views
        // update immediately, then refresh the shared snapshot + widget.
        let sample = StressSample(date: .now, bpm: 70, state: .calm)
        modelContext.insert(sample)
        let ok = (try? modelContext.save()) != nil
        if ok {
            Task { @MainActor in
                await SummaryWriter.writeSnapshot()
                WidgetCenter.shared.reloadAllTimelines()
            }
            appState.notifyDataChanged()
        }
        withAnimation {
            checkInToast = ok ? "Calm moment logged ✨" : "Couldn't log that"
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { checkInToast = nil }
        }
    }
}

/// The original "Last 24 Hours" history list, now its own tab, with a 30-day
/// calm-minutes trend and CSV export above the live samples.
private struct HistoryView: View {
    let samples: [StressSample]

    // The 24h `samples` drive the live list; the monthly trend + CSV need a
    // wider window, so query 30 days of samples just for those (bounded fetch).
    @Query private var allSamples: [StressSample]
    @State private var insights: Insights = .empty
    @State private var exportURL: URL?

    init(samples: [StressSample]) {
        self.samples = samples
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        _allSamples = Query(
            filter: #Predicate<StressSample> { $0.date >= thirtyDaysAgo },
            sort: \.date,
            order: .reverse
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            if samples.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "heart.text.square")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No stress samples yet")
                        .font(.headline)
                    Text("Wear your Apple Watch to start tracking.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                Spacer()
            } else {
                MonthlyTrendChart(trend: insights.monthlyTrend, goalMinutes: insights.goalMinutes)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                StressHistoryChartView(samples: samples)
                List(samples) { sample in
                    StressHistoryRow(sample: sample)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Last 24 Hours")
        .toolbar {
            if let exportURL {
                ShareLink(item: exportURL) {
                    Label("Export CSV", systemImage: "square.and.arrow.up")
                }
            }
        }
        .onAppear(perform: refresh)
        .onChange(of: allSamples.count) { _, _ in refresh() }
    }

    /// Recompute insights and prepare the CSV once per data change — never in
    /// `body`/`toolbar`, so view re-evaluation can't trigger repeated file I/O.
    private func refresh() {
        insights = InsightsEngine.compute(from: allSamples)
        exportURL = CalmMinutesCSV.writeTempFile(from: insights.monthlyTrend)
    }
}
