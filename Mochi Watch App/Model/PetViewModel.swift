import SwiftUI
import Combine
import Observation
import SwiftData
import Foundation
import WidgetKit

@Observable
final class PetViewModel {
    var state: StressState = .calm
    var bpm: Int = 0
    var hrvMs: Int = 0
    var maturity: PetMaturity.Level = .l0

    var evolutionStage: EvolutionStage { maturity.evolutionStage }

    private var heartRate: HeartRateService?
    @ObservationIgnored private var modelContext: ModelContext?
    @ObservationIgnored private var hasSeenInitialState: Bool = false

    init(heartRate: HeartRateService? = nil) {
        self.heartRate = heartRate
        if heartRate != nil {
            Task { @MainActor in
                startObserving()
            }
        }
    }

    @MainActor
    func attach(context: ModelContext) {
        self.modelContext = context
        recomputeMaturity()
    }

    @MainActor
    func refreshFromService() {
        guard let hr = heartRate, let v = hr.currentBPM else { return }
        bpm = v
        let newState = StressState.from(bpm: v)
        let previous = state
        state = newState
        if !hasSeenInitialState {
            hasSeenInitialState = true
            return
        }
        if newState != previous {
            persistTransition(to: newState, bpm: v)
        }
    }

    @MainActor
    private func persistTransition(to newState: StressState, bpm: Int) {
        guard let ctx = modelContext else { return }
        let sample = StressSample(date: .now, bpm: bpm, state: newState, syncID: UUID().uuidString)
        ctx.insert(sample)
        do {
            try ctx.save()
        } catch {
            return
        }
        WidgetCenter.shared.reloadAllTimelines()
        recomputeMaturity()
        // Bridge the real watch-measured sample (and refreshed summary) to the
        // iPhone. App Groups don't cross devices, so WatchConnectivity is the
        // only path to the iOS dashboard / widget / streak.
        WatchSyncSender.shared.send(samples: [sample])
        pushSummaryToPhone(now: sample.date)
    }

    /// Compute today's calm/over minutes + streak from the watch's own store and
    /// push them as the last-write-wins "current state" snapshot to the phone.
    @MainActor
    private func pushSummaryToPhone(now: Date) {
        guard let ctx = modelContext else { return }
        let reader = StressHistoryReader(context: ctx)
        let calm = (try? reader.calmMinutesToday(now: now)) ?? 0
        let over = (try? reader.overMinutesToday(now: now)) ?? 0
        let streak = DailySummaryStore.currentStreak(asOf: now, todayCalm: calm, todayOver: over)
        let summary = WatchSummaryDTO(
            calmMinutes: calm,
            overMinutes: over,
            streak: streak,
            currentStateRaw: state.rawValue,
            petStageRaw: maturity.evolutionStage.rawValue,
            goalMinutes: 30,
            asOf: now
        )
        WatchSyncSender.shared.send(summary: summary)
    }

    @MainActor
    private func recomputeMaturity() {
        guard let ctx = modelContext else { return }
        let descriptor = FetchDescriptor<StressSample>()
        if let samples = try? ctx.fetch(descriptor) {
            maturity = PetMaturity.compute(samples: samples)
        }
    }

    @MainActor
    private func startObserving() {
        func observe() {
            withObservationTracking {
                _ = heartRate?.currentBPM
            } onChange: {
                Task { @MainActor [weak self] in
                    self?.refreshFromService()
                    self?.startObserving()
                }
            }
        }
        observe()
    }

#if targetEnvironment(simulator)
    func cycle() {
        let all = StressState.allCases
        let currentIndex = all.firstIndex(of: state) ?? 0
        let nextIndex = (currentIndex + 1) % all.count
        let previous = state
        let next = all[nextIndex]
        state = next

        switch state {
        case .calm:
            bpm = 68
            hrvMs = 62
        case .okay:
            bpm = 78
            hrvMs = 48
        case .stressed:
            bpm = 96
            hrvMs = 32
        case .over:
            bpm = 112
            hrvMs = 22
        }

        if next != previous {
            Task { @MainActor in
                persistTransition(to: next, bpm: bpm)
            }
        }
    }
#endif
}
