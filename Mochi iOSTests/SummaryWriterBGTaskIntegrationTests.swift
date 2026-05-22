import BackgroundTasks
import Foundation
import XCTest
@testable import Mochi_iOS

final class SummaryWriterBGTaskIntegrationTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SummaryWriterBGTaskIntegrationTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir, FileManager.default.fileExists(atPath: tempDir.path) {
            try FileManager.default.removeItem(at: tempDir)
        }
        tempDir = nil
        try super.tearDownWithError()
    }

    func testRegisterForwardsExpectedIdentifierToScheduler() {
        let scheduler = FakeBGTaskScheduler()

        SummaryWriter.register(scheduler)

        XCTAssertEqual(scheduler.registerCalls.count, 1)
        XCTAssertEqual(scheduler.registerCalls.first?.identifier, SummaryWriter.bgTaskIdentifier)
        XCTAssertEqual(scheduler.registerCalls.first?.identifier, "com.pseudocowboy.mochi.summary.refresh")
        XCTAssertNil(scheduler.registerCalls.first?.queue, "register should pass nil queue (main)")
        XCTAssertNotNil(scheduler.registerCalls.first?.launchHandler, "scheduler must receive a launch handler closure")
    }

    func testHandleWritesSnapshotAndMarksTaskCompletedSuccess() throws {
        let url = tempDir.appendingPathComponent("summary.json")
        let task = FakeBGAppRefreshTask()
        let snapshot = SummarySnapshotFixtures.standard()

        let ok = SummaryWriter.handle(task: task, writeURL: url) { target in
            SummaryWriter.writeSnapshot(snapshot, to: target)
        }

        XCTAssertTrue(ok)
        XCTAssertEqual(task.completionResults, [true])
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(SummarySnapshot.self, from: Data(contentsOf: url))
        XCTAssertEqual(decoded, snapshot)
    }

    func testHandleReportsFailureWhenWriterReturnsFalse() {
        let url = tempDir.appendingPathComponent("summary.json")
        let task = FakeBGAppRefreshTask()

        let ok = SummaryWriter.handle(task: task, writeURL: url) { _ in false }

        XCTAssertFalse(ok)
        XCTAssertEqual(task.completionResults, [false])
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testHandleCompletesExactlyOncePerInvocation() {
        let url = tempDir.appendingPathComponent("summary.json")
        let task = FakeBGAppRefreshTask()

        SummaryWriter.handle(task: task, writeURL: url) { _ in true }
        SummaryWriter.handle(task: task, writeURL: url) { _ in true }

        XCTAssertEqual(task.completionResults, [true, true], "each handle call should complete the task exactly once")
    }

    func testScheduleNextRoutesThroughInjectedScheduler() throws {
        let scheduler = FakeBGTaskScheduler()
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "SummaryWriterBGTaskIntegrationTests-\(UUID().uuidString)"))
        defaults.set(true, forKey: SummaryWriter.defaultsKey)

        let ok = SummaryWriter.scheduleNext(scheduler: scheduler, defaults: defaults)

        XCTAssertTrue(ok)
        XCTAssertEqual(scheduler.submittedRequests.count, 1, "scheduleNext must route exactly one submit through the injected scheduler")
        XCTAssertEqual(scheduler.submittedRequests.first?.identifier, SummaryWriter.bgTaskIdentifier)
        XCTAssertTrue(scheduler.submittedRequests.first is BGAppRefreshTaskRequest, "scheduled request must be an app-refresh request")
    }

    func testScheduleNextDoesNotSubmitWhenDisabled() throws {
        let scheduler = FakeBGTaskScheduler()
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "SummaryWriterBGTaskIntegrationTests-\(UUID().uuidString)"))
        defaults.set(false, forKey: SummaryWriter.defaultsKey)

        let ok = SummaryWriter.scheduleNext(scheduler: scheduler, defaults: defaults)

        XCTAssertFalse(ok)
        XCTAssertTrue(scheduler.submittedRequests.isEmpty, "scheduleNext must not submit when background refresh is disabled")
    }
}
