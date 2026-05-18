import Foundation
import Observation

@Observable
@MainActor
final class BreathPresenter {
    var shouldPresentBreath: Bool = false

    init() {}

    func trigger() {
        shouldPresentBreath = true
    }
}
