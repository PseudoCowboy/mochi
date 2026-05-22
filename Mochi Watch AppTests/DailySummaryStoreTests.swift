import Foundation
import XCTest
@testable import Mochi_Watch_App

final class DailySummaryStoreTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUpWithError() throws {
        try super.setUpWithError()
        suiteName = "com.skywalker.Mochi.DailySummaryStoreTests.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        try super.tearDownWithError()
    }

    private func noonOnFixedDate() -> Date {
        // Pick a stable wall-clock date; tests are independent of "now".
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 19
        components.hour = 12
        components.minute = 0
        components.second = 0
        return Calendar.current.date(from: components)!
    }

    private func date(byAddingDays days: Int, to date: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: date)!
    }

    func testSaveAndLoadRoundTripForGivenDay() {
        let day = noonOnFixedDate()
        let summary = DailySummary(calm: 42, over: 7)

        DailySummaryStore.save(summary, on: day, defaults: defaults)
        let loaded = DailySummaryStore.load(day, defaults: defaults)

        XCTAssertEqual(loaded?.calm, 42)
        XCTAssertEqual(loaded?.over, 7)
    }

    func testLoadReturnsNilWhenMissing() {
        XCTAssertNil(DailySummaryStore.load(noonOnFixedDate(), defaults: defaults))
    }

    func testKeyIsStableForSameCalendarDay() {
        let morning = noonOnFixedDate().addingTimeInterval(-3 * 3600)
        let evening = noonOnFixedDate().addingTimeInterval(8 * 3600)
        XCTAssertEqual(DailySummaryStore.key(for: morning), DailySummaryStore.key(for: evening))
    }

    func testTodayAloneStreakIsOneWhenCalmDominates() {
        let now = noonOnFixedDate()
        let streak = DailySummaryStore.currentStreak(
            asOf: now,
            todayCalm: 10,
            todayOver: 0,
            defaults: defaults
        )
        XCTAssertEqual(streak, 1)
    }

    func testTodayAloneStreakIsZeroWhenCalmIsZero() {
        let now = noonOnFixedDate()
        let streak = DailySummaryStore.currentStreak(
            asOf: now,
            todayCalm: 0,
            todayOver: 0,
            defaults: defaults
        )
        XCTAssertEqual(streak, 0)
    }

    func testStreakAccumulatesForConsecutiveCalmDays() {
        let now = noonOnFixedDate()
        let yesterday = date(byAddingDays: -1, to: now)
        let twoDaysAgo = date(byAddingDays: -2, to: now)

        DailySummaryStore.save(DailySummary(calm: 8, over: 1), on: yesterday, defaults: defaults)
        DailySummaryStore.save(DailySummary(calm: 5, over: 0), on: twoDaysAgo, defaults: defaults)

        let streak = DailySummaryStore.currentStreak(
            asOf: now,
            todayCalm: 12,
            todayOver: 2,
            defaults: defaults
        )
        XCTAssertEqual(streak, 3)
    }

    func testStreakBreaksAtNonCalmDay() {
        let now = noonOnFixedDate()
        let yesterday = date(byAddingDays: -1, to: now)
        let twoDaysAgo = date(byAddingDays: -2, to: now)

        DailySummaryStore.save(DailySummary(calm: 4, over: 9), on: yesterday, defaults: defaults)
        DailySummaryStore.save(DailySummary(calm: 8, over: 1), on: twoDaysAgo, defaults: defaults)

        let streak = DailySummaryStore.currentStreak(
            asOf: now,
            todayCalm: 12,
            todayOver: 0,
            defaults: defaults
        )
        // Today contributes 1; yesterday is over-dominant → break. twoDaysAgo not counted.
        XCTAssertEqual(streak, 1)
    }

    func testStreakBreaksAtGapDayBecauseMissingEntryStopsIteration() {
        let now = noonOnFixedDate()
        let twoDaysAgo = date(byAddingDays: -2, to: now)

        // Skip yesterday entirely; load(yesterday) → nil → streak walk stops.
        DailySummaryStore.save(DailySummary(calm: 9, over: 0), on: twoDaysAgo, defaults: defaults)

        let streak = DailySummaryStore.currentStreak(
            asOf: now,
            todayCalm: 5,
            todayOver: 0,
            defaults: defaults
        )
        // FIXME(product-review): on a ≥2-day gap with calm activity today the
        // streak resets to 1 (today counts, prior calm days are inaccessible
        // because the missing intermediate day stops iteration). Confirm this
        // is the desired product semantics — alternative would be 0.
        XCTAssertEqual(streak, 1)
    }
}
