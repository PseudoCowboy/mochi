import Foundation
import Observation

struct BreathConfig: Equatable {
    let inhaleSeconds: Int
    let holdSeconds: Int
    let exhaleSeconds: Int
    let totalCycles: Int

    static let manualDefault = BreathConfig(inhaleSeconds: 4, holdSeconds: 7,
                                            exhaleSeconds: 8, totalCycles: 3)
    static let autoRecovery  = BreathConfig(inhaleSeconds: 4, holdSeconds: 4,
                                            exhaleSeconds: 6, totalCycles: 4)
}

extension String {
    static let breathAutoTriggerEnabledKey = "mochi.breath.autoTriggerEnabled"
}

@Observable
@MainActor
final class BreathPresenter {
    var shouldPresentBreath: Bool = false
    private(set) var pendingConfig: BreathConfig = .manualDefault

    init() {}

    func trigger(config: BreathConfig = .manualDefault) {
        pendingConfig = config
        shouldPresentBreath = true
    }
}
