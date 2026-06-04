import Foundation
import Observation

/// App-process router shared between the SwiftUI scene and App Intents so that
/// intents like "Start a breath session" can drive in-app navigation after
/// launching the app. Main-actor isolated; intents hop to it via `shared`.
@MainActor
@Observable
final class MochiAppState {
    static let shared = MochiAppState()

    /// Set by `StartBreathIntent`; observed by `ContentView` to present breathing.
    var pendingBreathRequest: Bool = false

    /// Bumped by check-in / breath intents so the dashboard refreshes on return.
    var refreshToken: Int = 0

    private init() {}

    func requestBreathSession() {
        pendingBreathRequest = true
    }

    func consumeBreathRequest() {
        pendingBreathRequest = false
    }

    func notifyDataChanged() {
        refreshToken &+= 1
    }
}
