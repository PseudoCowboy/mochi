import BackgroundTasks
import Foundation
import XCTest
@testable import Mochi_iOS

final class SummaryWriterBackgroundGatingTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUpWithError() throws {
        try super.setUpWithError()
        suiteName = "SummaryWriterBackgroundGatingTests-\(UUID().uuidString)"
        guard let suite = UserDefaults(suiteName: suiteName) else {
            throw XCTSkip("Could not create UserDefaults suite for gating test")
        }
        defaults = suite
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        try super.tearDownWithError()
    }

    func testScheduleNextSubmitsWhenDefaultsKeyIsTrue() {
        defaults.set(true, forKey: SummaryWriter.defaultsKey)
        let scheduler = FakeBGTaskScheduler()

        let submitted = SummaryWriter.scheduleNext(scheduler: scheduler, defaults: defaults)

        XCTAssertTrue(submitted)
        XCTAssertEqual(scheduler.submittedRequests.count, 1)
        XCTAssertEqual(scheduler.submittedRequests.first?.identifier, SummaryWriter.bgTaskIdentifier)
        XCTAssertTrue(scheduler.submittedRequests.first is BGAppRefreshTaskRequest)
    }

    func testScheduleNextDoesNotSubmitWhenDefaultsKeyIsFalse() {
        defaults.set(false, forKey: SummaryWriter.defaultsKey)
        let scheduler = FakeBGTaskScheduler()

        let submitted = SummaryWriter.scheduleNext(scheduler: scheduler, defaults: defaults)

        XCTAssertFalse(submitted)
        XCTAssertTrue(scheduler.submittedRequests.isEmpty, "no request should reach the scheduler when the toggle is off")
    }

    func testScheduleNextDefaultsToEnabledWhenKeyAbsent() {
        // No value written for SummaryWriter.defaultsKey — expect default-enabled behavior.
        let scheduler = FakeBGTaskScheduler()

        let submitted = SummaryWriter.scheduleNext(scheduler: scheduler, defaults: defaults)

        XCTAssertTrue(submitted)
        XCTAssertEqual(scheduler.submittedRequests.count, 1)
    }

    func testScheduleNextReturnsFalseWhenSchedulerThrows() {
        defaults.set(true, forKey: SummaryWriter.defaultsKey)
        let scheduler = FakeBGTaskScheduler()
        struct StubbedError: Error {}
        scheduler.submitError = StubbedError()

        let submitted = SummaryWriter.scheduleNext(scheduler: scheduler, defaults: defaults)

        XCTAssertFalse(submitted)
        XCTAssertTrue(scheduler.submittedRequests.isEmpty)
    }
}
