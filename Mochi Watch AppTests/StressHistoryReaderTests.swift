import Foundation
import SwiftData
import XCTest
@testable import Mochi_Watch_App

final class StressHistoryReaderTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: Schema([StressSample.self]),
            configurations: configuration
        )
        context = ModelContext(container)
    }

    override func tearDownWithError() throws {
        context = nil
        container = nil
        try super.tearDownWithError()
    }

    private func insert(_ sample: StressSample) throws {
        context.insert(sample)
        try context.save()
    }

    private func noon() -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = 12
        components.minute = 0
        components.second = 0
        return Calendar.current.date(from: components)!
    }

    func testReturnsZeroWhenNoSamplesExist() throws {
        let reader = StressHistoryReader(context: context)
        let minutes = try reader.minutesToday(in: .calm, now: noon())
        XCTAssertEqual(minutes, 0)
    }

    func testCountsGapBetweenTwoCalmSamplesUpToCap() throws {
        let now = noon()
        let first = now.addingTimeInterval(-600)   // 10 minutes ago
        let second = now.addingTimeInterval(-240)  // 4 minutes ago; gap = 360s, capped to 300s

        try insert(StressSample(date: first, bpm: 70, state: .calm))
        try insert(StressSample(date: second, bpm: 72, state: .calm))

        let reader = StressHistoryReader(context: context)

        // 300s (capped first→second) + min(240s, 300s) trailing = 540s = 9 minutes
        let calm = try reader.minutesToday(in: .calm, now: now)
        XCTAssertEqual(calm, 9)
    }

    func testGapAttributedToPreviousSampleStateOnly() throws {
        let now = noon()
        let calmTime = now.addingTimeInterval(-200) // 200s before now
        let overTime = now.addingTimeInterval(-50)  // 50s before now

        try insert(StressSample(date: calmTime, bpm: 70, state: .calm))
        try insert(StressSample(date: overTime, bpm: 140, state: .over))

        let reader = StressHistoryReader(context: context)

        // calm: gap from calmTime→overTime = 150s (under cap); no trailing for calm
        let calm = try reader.minutesToday(in: .calm, now: now)
        // over: no in-between gap; trailing = 50s (under cap)
        let over = try reader.minutesToday(in: .over, now: now)

        XCTAssertEqual(calm, 150 / 60) // 2
        XCTAssertEqual(over, 50 / 60)  // 0
    }

    func testTrailingEdgeIsCappedAt300Seconds() throws {
        let now = noon()
        let only = now.addingTimeInterval(-1_000) // 1000s ago, only sample

        try insert(StressSample(date: only, bpm: 72, state: .calm))

        let reader = StressHistoryReader(context: context)
        // Only the trailing edge contributes (no second sample), capped to 300s = 5 minutes
        let calm = try reader.minutesToday(in: .calm, now: now)
        XCTAssertEqual(calm, 5)
    }

    func testIgnoresSamplesBeforeStartOfDay() throws {
        let now = noon()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!
            .addingTimeInterval(-3600) // well before today's startOfDay

        try insert(StressSample(date: yesterday, bpm: 70, state: .calm))

        let reader = StressHistoryReader(context: context)
        let calm = try reader.minutesToday(in: .calm, now: now)
        XCTAssertEqual(calm, 0)
    }

    func testStateFilterMatchesOnlyRequestedState() throws {
        let now = noon()
        let t0 = now.addingTimeInterval(-120) // 120s ago, only sample

        try insert(StressSample(date: t0, bpm: 140, state: .over))

        let reader = StressHistoryReader(context: context)
        // Trailing edge counts toward .over, not .calm
        XCTAssertEqual(try reader.minutesToday(in: .calm, now: now), 0)
        XCTAssertEqual(try reader.minutesToday(in: .over, now: now), 2)
    }
}
