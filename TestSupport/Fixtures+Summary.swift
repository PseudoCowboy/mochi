import Foundation

#if canImport(Mochi_Watch_App)
@testable import Mochi_Watch_App
#endif
#if canImport(Mochi_iOS)
@testable import Mochi_iOS
#endif

enum SummarySnapshotFixtures {
    /// Same anchor as `StressSampleFixtures.anchor`.
    static let anchor = Date(timeIntervalSince1970: 1_700_000_000)

    static func standard(asOf: Date = anchor) -> SummarySnapshot {
        SummarySnapshot(
            calmMinutes: 312,
            overMinutes: 18,
            streak: 4,
            asOf: asOf
        )
    }

    static func zeroed(asOf: Date = anchor) -> SummarySnapshot {
        SummarySnapshot(
            calmMinutes: 0,
            overMinutes: 0,
            streak: 0,
            asOf: asOf
        )
    }

    static func longStreak(asOf: Date = anchor) -> SummarySnapshot {
        SummarySnapshot(
            calmMinutes: 540,
            overMinutes: 6,
            streak: 21,
            asOf: asOf
        )
    }
}
