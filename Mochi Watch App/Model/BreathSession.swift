import Foundation
import Observation

enum BreathPhase: Equatable {
    case idle
    case inhale
    case hold
    case exhale
    case done
}

@Observable
@MainActor
final class BreathSessionViewState {
    var phase: BreathPhase = .idle
    var remainingSeconds: Int = 0
    var cycleIndex: Int = 0
    var totalCycles: Int = 3

    init(totalCycles: Int = 3) {
        self.totalCycles = totalCycles
    }
}

actor BreathSession {
    private let totalCycles: Int
    nonisolated let state: BreathSessionViewState
    nonisolated let inhaleSeconds: Int
    nonisolated let holdSeconds: Int
    nonisolated let exhaleSeconds: Int
    private let tickDuration: Duration
    private var stopped: Bool = false

    init(
        totalCycles: Int = 3,
        inhaleSeconds: Int = 4,
        holdSeconds: Int = 7,
        exhaleSeconds: Int = 8,
        tickDuration: Duration = .seconds(1),
        state: BreathSessionViewState
    ) {
        self.totalCycles = totalCycles
        self.inhaleSeconds = inhaleSeconds
        self.holdSeconds = holdSeconds
        self.exhaleSeconds = exhaleSeconds
        self.tickDuration = tickDuration
        self.state = state
    }

    func start() async {
        stopped = false
        let cycles = totalCycles
        let stateRef = state
        await MainActor.run {
            stateRef.totalCycles = cycles
            stateRef.cycleIndex = 0
            stateRef.phase = .idle
            stateRef.remainingSeconds = 0
        }

        let phases: [(BreathPhase, Int)] = [
            (.inhale, inhaleSeconds),
            (.hold, holdSeconds),
            (.exhale, exhaleSeconds)
        ]

        cycleLoop: for cycle in 0..<cycles {
            if stopped || Task.isCancelled { break }
            await MainActor.run { stateRef.cycleIndex = cycle }

            for (phase, seconds) in phases {
                if stopped || Task.isCancelled { break cycleLoop }
                await MainActor.run {
                    stateRef.phase = phase
                    stateRef.remainingSeconds = seconds
                }

                for _ in 0..<seconds {
                    if stopped || Task.isCancelled { break cycleLoop }
                    do {
                        try await Task.sleep(for: tickDuration)
                    } catch {
                        break cycleLoop
                    }
                    if stopped || Task.isCancelled { break cycleLoop }
                    await MainActor.run {
                        if stateRef.remainingSeconds > 0 {
                            stateRef.remainingSeconds -= 1
                        }
                    }
                }
            }
        }

        await MainActor.run {
            stateRef.phase = .done
            stateRef.remainingSeconds = 0
        }
    }

    func end() {
        stopped = true
    }
}
