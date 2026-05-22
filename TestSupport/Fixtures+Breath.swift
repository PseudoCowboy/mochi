import Foundation

#if canImport(Mochi_Watch_App)
@testable import Mochi_Watch_App
#endif
#if canImport(Mochi_iOS)
@testable import Mochi_iOS
#endif

#if canImport(Mochi_Watch_App)
enum BreathSessionFixtures {
    @MainActor
    static func state(
        phase: BreathPhase,
        remainingSeconds: Int? = nil,
        cycleIndex: Int = 0,
        totalCycles: Int = 3
    ) -> BreathSessionViewState {
        let s = BreathSessionViewState(totalCycles: totalCycles)
        s.phase = phase
        s.cycleIndex = cycleIndex
        s.remainingSeconds = remainingSeconds ?? Self.defaultRemaining(for: phase)
        return s
    }

    @MainActor static func inhale() -> BreathSessionViewState { state(phase: .inhale) }
    @MainActor static func hold() -> BreathSessionViewState { state(phase: .hold) }
    @MainActor static func exhale() -> BreathSessionViewState { state(phase: .exhale) }
    @MainActor static func done() -> BreathSessionViewState { state(phase: .done) }

    private static func defaultRemaining(for phase: BreathPhase) -> Int {
        switch phase {
        case .inhale: return 4
        case .hold: return 7
        case .exhale: return 8
        case .done, .idle: return 0
        }
    }
}
#endif
