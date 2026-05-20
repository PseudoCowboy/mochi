import Foundation

#if canImport(Mochi_Watch_App)
@testable import Mochi_Watch_App
#endif
#if canImport(Mochi_iOS)
@testable import Mochi_iOS
#endif

enum StressSampleFixtures {
    /// Fixed reference instant shared across all time-dependent fixtures.
    /// Wed, 14 Nov 2023 22:13:20 GMT.
    static let anchor = Date(timeIntervalSince1970: 1_700_000_000)

    static func empty() -> [StressSample] { [] }

    /// 12 samples spanning the 12 hours preceding `anchor`, one per hour.
    static func partialDay(now: Date = anchor) -> [StressSample] {
        stride(from: 12, through: 1, by: -1).map { hoursAgo -> StressSample in
            let date = now.addingTimeInterval(TimeInterval(-hoursAgo * 3600))
            return sample(at: date, indexInDay: 12 - hoursAgo)
        }
    }

    /// 24 samples spanning the 24 hours preceding `anchor`, one per hour.
    static func fullDay(now: Date = anchor) -> [StressSample] {
        stride(from: 24, through: 1, by: -1).map { hoursAgo -> StressSample in
            let date = now.addingTimeInterval(TimeInterval(-hoursAgo * 3600))
            return sample(at: date, indexInDay: 24 - hoursAgo)
        }
    }

    /// Deterministic bpm/state pattern so chart colors and y-values do not drift.
    private static func sample(at date: Date, indexInDay: Int) -> StressSample {
        let pattern: [(bpm: Int, state: StressState)] = [
            (62, .calm), (66, .calm), (70, .calm), (74, .okay),
            (82, .okay), (95, .stressed), (108, .stressed), (135, .over)
        ]
        let entry = pattern[indexInDay % pattern.count]
        return StressSample(date: date, bpm: entry.bpm, state: entry.state)
    }
}
