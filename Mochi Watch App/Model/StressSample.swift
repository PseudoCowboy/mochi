import Foundation
import SwiftData

@Model
final class StressSample {
    var date: Date
    var bpm: Int
    var stateRaw: Int

    init(date: Date, bpm: Int, state: StressState) {
        self.date = date
        self.bpm = bpm
        self.stateRaw = state.rawValue
    }

    var state: StressState {
        StressState(rawValue: stateRaw) ?? .calm
    }
}
