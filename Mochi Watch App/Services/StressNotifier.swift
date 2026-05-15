import Foundation
import Observation
import UserNotifications
import WatchKit

@MainActor
final class StressNotifier {
    private weak var viewModel: PetViewModel?
    private var lastState: StressState?
    private var isObserving: Bool = false

    private let throttle: TimeInterval = 30 * 60
    private let defaultsKey = "mochi.stressNotifier.lastOverAt"
    private let center = UNUserNotificationCenter.current()
    private let defaults = UserDefaults.standard

    init(viewModel: PetViewModel) {
        self.viewModel = viewModel
    }

    func requestAuthorization() async {
        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            return
        }
    }

    func start() {
        guard !isObserving else { return }
        isObserving = true
        seedInitialState()
        observe()
    }

    private func seedInitialState() {
        lastState = viewModel?.state
    }

    private func observe() {
        withObservationTracking {
            _ = viewModel?.state
        } onChange: {
            Task { @MainActor [weak self] in
                guard let self, let state = self.viewModel?.state else { return }
                self.handle(state: state)
                self.observe()
            }
        }
    }

    private func handle(state current: StressState) {
        let previous = lastState
        lastState = current

        guard previous != .over, current == .over else { return }

        let now = Date()
        if let last = lastOverFiredAt, now.timeIntervalSince(last) < throttle {
            return
        }

        WKInterfaceDevice.current().play(.notification)
        fireOverNotification()
        lastOverFiredAt = now
    }

    private func fireOverNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Mochi"
        content.body = "Mochi needs a breather 💚"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "mochi.stress.over.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        center.add(request, withCompletionHandler: nil)
    }

    private var lastOverFiredAt: Date? {
        get {
            let t = defaults.double(forKey: defaultsKey)
            guard t > 0 else { return nil }
            return Date(timeIntervalSince1970: t)
        }
        set {
            if let v = newValue {
                defaults.set(v.timeIntervalSince1970, forKey: defaultsKey)
            } else {
                defaults.removeObject(forKey: defaultsKey)
            }
        }
    }
}
