import Foundation
import XCTest
@testable import Mochi_Watch_App

final class StressNotifierTests: XCTestCase {
    private let throttle: TimeInterval = 30 * 60

    func testFiresWhenNoPriorNotification() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        XCTAssertTrue(
            StressNotifier.shouldFire(now: now, lastFiredAt: nil, throttle: throttle)
        )
    }

    func testDoesNotFireOneSecondBeforeCooldownExpires() {
        let last = Date(timeIntervalSince1970: 1_700_000_000)
        let now = last.addingTimeInterval(throttle - 1) // 29:59
        XCTAssertFalse(
            StressNotifier.shouldFire(now: now, lastFiredAt: last, throttle: throttle)
        )
    }

    func testFiresExactlyAtCooldownBoundary() {
        let last = Date(timeIntervalSince1970: 1_700_000_000)
        let now = last.addingTimeInterval(throttle) // 30:00
        XCTAssertTrue(
            StressNotifier.shouldFire(now: now, lastFiredAt: last, throttle: throttle)
        )
    }

    func testFiresOneSecondAfterCooldownBoundary() {
        let last = Date(timeIntervalSince1970: 1_700_000_000)
        let now = last.addingTimeInterval(throttle + 1) // 30:01
        XCTAssertTrue(
            StressNotifier.shouldFire(now: now, lastFiredAt: last, throttle: throttle)
        )
    }

    func testNonZeroThrottleIsRespectedExactly() {
        let last = Date(timeIntervalSince1970: 1_700_000_000)
        let custom: TimeInterval = 60
        XCTAssertFalse(
            StressNotifier.shouldFire(now: last.addingTimeInterval(59), lastFiredAt: last, throttle: custom)
        )
        XCTAssertTrue(
            StressNotifier.shouldFire(now: last.addingTimeInterval(60), lastFiredAt: last, throttle: custom)
        )
    }
}
