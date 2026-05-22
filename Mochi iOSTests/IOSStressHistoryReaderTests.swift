import Foundation
import SwiftData
import XCTest
@testable import Mochi_iOS

@MainActor
final class IOSStressHistoryReaderTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUp() async throws {
        try await super.setUp()
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: Schema([StressSample.self]),
            configurations: configuration
        )
        context = ModelContext(container)
    }

    override func tearDown() async throws {
        context = nil
        container = nil
        try await super.tearDown()
    }

    private func insert(_ sample: StressSample) throws {
        context.insert(sample)
        try context.save()
    }

    private func fixedNow() -> Date {
        Date(timeIntervalSince1970: 1_700_000_000)
    }

    func testRecentSamplesIncludesOnlyEntriesAfterCutoff() throws {
        let now = fixedNow()
        let cutoff = now.addingTimeInterval(-3600)

        try insert(StressSample(date: now.addingTimeInterval(-7200), bpm: 65, state: .calm)) // before
        try insert(StressSample(date: now.addingTimeInterval(-1800), bpm: 70, state: .calm)) // after
        try insert(StressSample(date: now.addingTimeInterval(-60), bpm: 140, state: .over)) // after

        let reader = StressHistoryReader(context: context)
        let samples = try reader.recentSamples(since: cutoff)

        XCTAssertEqual(samples.count, 2)
        XCTAssertTrue(samples.allSatisfy { $0.date >= cutoff })
    }

    func testRecentSamplesAreSortedByDateDescending() throws {
        let now = fixedNow()
        let earlier = now.addingTimeInterval(-600)
        let middle = now.addingTimeInterval(-300)
        let recent = now.addingTimeInterval(-60)

        try insert(StressSample(date: middle, bpm: 70, state: .calm))
        try insert(StressSample(date: recent, bpm: 140, state: .over))
        try insert(StressSample(date: earlier, bpm: 65, state: .calm))

        let reader = StressHistoryReader(context: context)
        let samples = try reader.recentSamples(since: now.addingTimeInterval(-1800))

        XCTAssertEqual(samples.map(\.date), [recent, middle, earlier])
    }

    func testLast24HoursExcludesOlderThanOneDay() throws {
        let now = fixedNow()
        let justInside = now.addingTimeInterval(-(24 * 3600) + 60) // 23h59m ago
        let justOutside = now.addingTimeInterval(-(24 * 3600) - 60) // 24h01m ago

        try insert(StressSample(date: justInside, bpm: 70, state: .calm))
        try insert(StressSample(date: justOutside, bpm: 72, state: .calm))

        let reader = StressHistoryReader(context: context)
        let samples = try reader.last24Hours(now: now)

        XCTAssertEqual(samples.count, 1)
        XCTAssertEqual(samples.first?.date, justInside)
    }

    func testFetch24hReturnsAscendingOrder() throws {
        let now = fixedNow()
        let oldest = now.addingTimeInterval(-3600)
        let middle = now.addingTimeInterval(-1800)
        let newest = now.addingTimeInterval(-60)

        try insert(StressSample(date: middle, bpm: 80, state: .calm))
        try insert(StressSample(date: newest, bpm: 95, state: .stressed))
        try insert(StressSample(date: oldest, bpm: 68, state: .calm))

        let reader = StressHistoryReader(context: context)
        let samples = try reader.fetch24h(now: now)

        XCTAssertEqual(samples.map(\.date), [oldest, middle, newest])
    }

    func testRecentSamplesIsEmptyWhenStoreEmpty() throws {
        let reader = StressHistoryReader(context: context)
        let samples = try reader.recentSamples(since: fixedNow().addingTimeInterval(-3600))
        XCTAssertTrue(samples.isEmpty)
    }

    func testAppGroupIdentifierConstantMatchesSpec() {
        XCTAssertEqual(StressHistoryReader.appGroupID, "group.com.pseudocowboy.mochi")
    }
}
