import Foundation

/// Wire contract for the watch → phone WatchConnectivity bridge.
///
/// All payloads are plain plist-serializable dictionaries (`String`, `NSNumber`,
/// `Date`, arrays, nested dictionaries) so they can travel through
/// `transferUserInfo` / `updateApplicationContext` without a `Data` round-trip.
/// Both the watch sender and the iOS receiver import this single source of truth
/// so the keys can never drift.
enum WatchSyncKeys {
    /// Discriminates the kind of `userInfo` payload (`stressSamples`).
    static let payloadType = "mochi.sync.type"
    /// Array of encoded `StressSampleDTO` dictionaries.
    static let samples = "mochi.sync.samples"

    // Per-sample fields.
    static let sampleID = "id"
    static let sampleDate = "date"
    static let sampleBPM = "bpm"
    static let sampleStateRaw = "stateRaw"

    // Summary applicationContext fields.
    static let calmMinutes = "calmMinutes"
    static let overMinutes = "overMinutes"
    static let streak = "streak"
    static let stateRaw = "currentStateRaw"
    static let stageRaw = "petStageRaw"
    static let asOf = "asOf"
    static let goalMinutes = "goalMinutes"
}

enum WatchSyncPayloadType {
    static let stressSamples = "stressSamples"
}

/// A single stress sample on the wire. Carries a stable `id` so the receiver can
/// dedup across `transferUserInfo` retries / re-deliveries and never double-insert.
struct StressSampleDTO: Equatable {
    let id: String
    let date: Date
    let bpm: Int
    let stateRaw: Int

    var dictionary: [String: Any] {
        [
            WatchSyncKeys.sampleID: id,
            WatchSyncKeys.sampleDate: date,
            WatchSyncKeys.sampleBPM: bpm,
            WatchSyncKeys.sampleStateRaw: stateRaw,
        ]
    }

    init(id: String, date: Date, bpm: Int, stateRaw: Int) {
        self.id = id
        self.date = date
        self.bpm = bpm
        self.stateRaw = stateRaw
    }

    init?(dictionary: [String: Any]) {
        guard let id = dictionary[WatchSyncKeys.sampleID] as? String,
              let date = dictionary[WatchSyncKeys.sampleDate] as? Date,
              let bpm = dictionary[WatchSyncKeys.sampleBPM] as? Int,
              let stateRaw = dictionary[WatchSyncKeys.sampleStateRaw] as? Int else {
            return nil
        }
        self.id = id
        self.date = date
        self.bpm = bpm
        self.stateRaw = stateRaw
    }
}

/// The "current state" snapshot pushed via `updateApplicationContext`
/// (last-write-wins). Mirrors what the iOS dashboard / widget need.
struct WatchSummaryDTO: Equatable {
    let calmMinutes: Int
    let overMinutes: Int
    let streak: Int
    let currentStateRaw: Int
    let petStageRaw: Int
    let goalMinutes: Int
    let asOf: Date

    var applicationContext: [String: Any] {
        [
            WatchSyncKeys.calmMinutes: calmMinutes,
            WatchSyncKeys.overMinutes: overMinutes,
            WatchSyncKeys.streak: streak,
            WatchSyncKeys.stateRaw: currentStateRaw,
            WatchSyncKeys.stageRaw: petStageRaw,
            WatchSyncKeys.goalMinutes: goalMinutes,
            WatchSyncKeys.asOf: asOf,
        ]
    }

    init(
        calmMinutes: Int,
        overMinutes: Int,
        streak: Int,
        currentStateRaw: Int,
        petStageRaw: Int,
        goalMinutes: Int,
        asOf: Date
    ) {
        self.calmMinutes = calmMinutes
        self.overMinutes = overMinutes
        self.streak = streak
        self.currentStateRaw = currentStateRaw
        self.petStageRaw = petStageRaw
        self.goalMinutes = goalMinutes
        self.asOf = asOf
    }

    init?(applicationContext: [String: Any]) {
        guard let calm = applicationContext[WatchSyncKeys.calmMinutes] as? Int,
              let over = applicationContext[WatchSyncKeys.overMinutes] as? Int,
              let streak = applicationContext[WatchSyncKeys.streak] as? Int,
              let asOf = applicationContext[WatchSyncKeys.asOf] as? Date else {
            return nil
        }
        self.calmMinutes = calm
        self.overMinutes = over
        self.streak = streak
        self.currentStateRaw = applicationContext[WatchSyncKeys.stateRaw] as? Int ?? 0
        self.petStageRaw = applicationContext[WatchSyncKeys.stageRaw] as? Int ?? 0
        self.goalMinutes = applicationContext[WatchSyncKeys.goalMinutes] as? Int ?? 30
        self.asOf = asOf
    }
}
