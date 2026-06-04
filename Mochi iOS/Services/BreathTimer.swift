import Foundation
import Observation

/// Lightweight guided-breathing engine for the iOS app. Self-contained (the
/// watch app's `BreathSession` actor is watch-target only) but uses the same
/// 4-7-8 defaults so both platforms feel identical.
enum IOSBreathPhase: Equatable {
    case idle, inhale, hold, exhale, done

    var label: String {
        switch self {
        case .idle: return "Get ready"
        case .inhale: return "Breathe in"
        case .hold: return "Hold"
        case .exhale: return "Breathe out"
        case .done: return "Done"
        }
    }

    /// Target scale for the breathing orb in this phase.
    var orbScale: Double {
        switch self {
        case .idle, .exhale, .done: return 0.6
        case .inhale, .hold: return 1.0
        }
    }
}

@MainActor
@Observable
final class BreathTimer {
    var phase: IOSBreathPhase = .idle
    var remainingSeconds: Int = 0
    var cycleIndex: Int = 0

    let totalCycles: Int
    let inhaleSeconds: Int
    let holdSeconds: Int
    let exhaleSeconds: Int

    private var task: Task<Void, Never>?
    private let tick: Duration

    init(
        totalCycles: Int = 3,
        inhaleSeconds: Int = 4,
        holdSeconds: Int = 7,
        exhaleSeconds: Int = 8,
        tick: Duration = .seconds(1)
    ) {
        self.totalCycles = totalCycles
        self.inhaleSeconds = inhaleSeconds
        self.holdSeconds = holdSeconds
        self.exhaleSeconds = exhaleSeconds
        self.tick = tick
    }

    var isRunning: Bool { task != nil }

    func start() {
        guard task == nil else { return }
        cycleIndex = 0
        phase = .idle
        let phases: [(IOSBreathPhase, Int)] = [
            (.inhale, inhaleSeconds),
            (.hold, holdSeconds),
            (.exhale, exhaleSeconds)
        ]
        task = Task { [weak self] in
            guard let self else { return }
            for cycle in 0..<self.totalCycles {
                if Task.isCancelled { break }
                self.cycleIndex = cycle
                for (ph, seconds) in phases {
                    if Task.isCancelled { break }
                    self.phase = ph
                    self.remainingSeconds = seconds
                    for _ in 0..<seconds {
                        if Task.isCancelled { break }
                        try? await Task.sleep(for: self.tick)
                        if Task.isCancelled { break }
                        if self.remainingSeconds > 0 { self.remainingSeconds -= 1 }
                    }
                }
            }
            if !Task.isCancelled {
                self.phase = .done
                self.remainingSeconds = 0
            }
            self.task = nil
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }
}
