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
    private var stopped: Bool = false

    private static let inhaleSeconds: Int = 4
    private static let holdSeconds: Int = 7
    private static let exhaleSeconds: Int = 8

    init(totalCycles: Int = 3, state: BreathSessionViewState) {
        self.totalCycles = totalCycles
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
            (.inhale, Self.inhaleSeconds),
            (.hold, Self.holdSeconds),
            (.exhale, Self.exhaleSeconds)
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
                        try await Task.sleep(for: .seconds(1))
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
