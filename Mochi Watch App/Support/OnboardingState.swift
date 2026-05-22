import Foundation
import Observation

@Observable
final class OnboardingState {
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let key = "didCompleteOnboarding"

    var didCompleteOnboarding: Bool {
        didSet {
            defaults.set(didCompleteOnboarding, forKey: key)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.didCompleteOnboarding = defaults.bool(forKey: "didCompleteOnboarding")
    }
}
