import Foundation
import Observation

@MainActor
final class OverSustainTracker {
    typealias Now = () -> Date
    typealias Schedule = (TimeInterval, @escaping @MainActor () -> Void) -> any OverSustainCancellable

    private weak var viewModel: PetViewModel?
    private let sustainSeconds: TimeInterval
    private let isEnabled: () -> Bool
    private let now: Now
    private let schedule: Schedule
    private let onSustainedOver: @MainActor () -> Void

    private var isObserving: Bool = false
    private var lastState: StressState?
    private var episodeStartedAt: Date?
    private var pendingTimer: (any OverSustainCancellable)?
    private var hasFiredForCurrentEpisode: Bool = false

    init(viewModel: PetViewModel,
         sustainSeconds: TimeInterval = 120,
         isEnabled: @escaping () -> Bool,
         now: @escaping Now = Date.init,
         schedule: @escaping Schedule = OverSustainTracker.defaultSchedule,
         onSustainedOver: @escaping @MainActor () -> Void) {
        self.viewModel = viewModel
        self.sustainSeconds = sustainSeconds
        self.isEnabled = isEnabled
        self.now = now
        self.schedule = schedule
        self.onSustainedOver = onSustainedOver
    }

    func start() {
        guard !isObserving else { return }
        isObserving = true
        let current = viewModel?.state
        lastState = current
        if current == .over {
            beginEpisode()
        }
        observe()
    }

    func stop() {
        isObserving = false
        cancelTimer()
        episodeStartedAt = nil
        hasFiredForCurrentEpisode = false
    }

    private func observe() {
        withObservationTracking {
            _ = viewModel?.state
        } onChange: {
            Task { @MainActor [weak self] in
                guard let self, self.isObserving else { return }
                if let state = self.viewModel?.state {
                    self.handle(state: state)
                }
                self.observe()
            }
        }
    }

    private func handle(state current: StressState) {
        let previous = lastState
        lastState = current

        if current == .over {
            if previous != .over {
                beginEpisode()
            }
        } else {
            endEpisode()
        }
    }

    private func beginEpisode() {
        cancelTimer()
        hasFiredForCurrentEpisode = false
        episodeStartedAt = now()
        pendingTimer = schedule(sustainSeconds) { [weak self] in
            self?.timerFired()
        }
    }

    private func endEpisode() {
        cancelTimer()
        episodeStartedAt = nil
        hasFiredForCurrentEpisode = false
    }

    private func timerFired() {
        pendingTimer = nil
        guard isObserving else { return }
        guard viewModel?.state == .over else { return }
        guard !hasFiredForCurrentEpisode else { return }
        hasFiredForCurrentEpisode = true
        guard isEnabled() else { return }
        onSustainedOver()
    }

    private func cancelTimer() {
        pendingTimer?.cancel()
        pendingTimer = nil
    }

    static let defaultSchedule: Schedule = { interval, action in
        let task = Task { @MainActor in
            let nanos = UInt64((interval * 1_000_000_000).rounded())
            try? await Task.sleep(nanoseconds: nanos)
            if Task.isCancelled { return }
            action()
        }
        return OverSustainTaskCancellable(task: task)
    }
}

protocol OverSustainCancellable: AnyObject {
    func cancel()
}

private final class OverSustainTaskCancellable: OverSustainCancellable {
    private let task: Task<Void, Never>
    init(task: Task<Void, Never>) { self.task = task }
    func cancel() { task.cancel() }
}
