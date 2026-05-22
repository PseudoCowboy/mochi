import Foundation
import SwiftData

struct StressHistoryReader {
    let context: ModelContext

    private static let gapCapSeconds: TimeInterval = 300

    func calmMinutesToday(now: Date = .now) throws -> Int {
        try minutesToday(in: .calm, now: now)
    }

    func overMinutesToday(now: Date = .now) throws -> Int {
        try minutesToday(in: .over, now: now)
    }

    func minutesToday(in state: StressState, now: Date) throws -> Int {
        let startOfDay = Calendar.current.startOfDay(for: now)
        let descriptor = FetchDescriptor<StressSample>(
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )

        let all = try context.fetch(descriptor)
        let samples = all.filter { $0.date >= startOfDay && $0.date <= now }
        guard !samples.isEmpty else { return 0 }

        var totalSeconds: TimeInterval = 0

        if samples.count >= 2 {
            for index in 0..<(samples.count - 1) {
                let prev = samples[index]
                let next = samples[index + 1]
                guard prev.state == state else { continue }
                let gap = next.date.timeIntervalSince(prev.date)
                guard gap > 0 else { continue }
                totalSeconds += min(gap, Self.gapCapSeconds)
            }
        }

        if let last = samples.last, last.state == state {
            let trailing = now.timeIntervalSince(last.date)
            if trailing > 0 {
                totalSeconds += min(trailing, Self.gapCapSeconds)
            }
        }

        return Int(totalSeconds / 60)
    }
}
