import Foundation
import SwiftData

@Model
final class StressSample {
    var date: Date
    var bpm: Int
    var stateRaw: Int
    /// Stable identity used to dedup samples synced across the watch/phone
    /// WatchConnectivity bridge. `nil` for samples created before the bridge
    /// existed (lightweight SwiftData migration adds the column as optional).
    var syncID: String?

    init(date: Date, bpm: Int, state: StressState, syncID: String? = nil) {
        self.date = date
        self.bpm = bpm
        self.stateRaw = state.rawValue
        self.syncID = syncID
    }

    var state: StressState {
        StressState(rawValue: stateRaw) ?? .calm
    }
}
