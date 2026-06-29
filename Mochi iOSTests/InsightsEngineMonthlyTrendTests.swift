import Foundation
import XCTest
@testable import Mochi_iOS

final class InsightsEngineMonthlyTrendTests: XCTestCase {
    private func fixedNow() -> Date {
        Date(timeIntervalSince1970: 1_700_000_000)
    }

    func testMonthlyTrendHasThirtyDaysOldestToNewest() {
        let now = fixedNow()
        // Fixed Gregorian/UTC calendar so day boundaries are deterministic
        // regardless of the test host's timezone or locale.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        // A couple of samples so compute has something to attribute; the trend
        // shape (count + ordering) shouldn't depend on sample volume.
        let samples = [
            StressSample(date: now.addingTimeInterval(-3600), bpm: 65, state: .calm),
            StressSample(date: now.addingTimeInterval(-1800), bpm: 140, state: .over)
        ]

        let insights = InsightsEngine.compute(from: samples, now: now, calendar: calendar)

        XCTAssertEqual(insights.monthlyTrend.count, 30)

        let dates = insights.monthlyTrend.map(\.date)
        XCTAssertEqual(dates, dates.sorted(), "monthly trend should be oldest → newest")

        let startOfToday = calendar.startOfDay(for: now)
        XCTAssertEqual(insights.monthlyTrend.last?.date, startOfToday, "last entry is today")
        let expectedFirst = calendar.date(byAdding: .day, value: -29, to: startOfToday)
        XCTAssertEqual(insights.monthlyTrend.first?.date, expectedFirst, "first entry is 29 days back")
    }

    func testMonthlyTrendEmptyWhenNoSamples() {
        XCTAssertTrue(Insights.empty.monthlyTrend.isEmpty)
    }
}
