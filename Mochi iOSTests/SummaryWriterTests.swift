import Foundation
import XCTest
@testable import Mochi_iOS

final class SummaryWriterTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SummaryWriterTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir, FileManager.default.fileExists(atPath: tempDir.path) {
            try FileManager.default.removeItem(at: tempDir)
        }
        tempDir = nil
        try super.tearDownWithError()
    }

    private func makeSnapshot(
        calm: Int = 11,
        over: Int = 2,
        streak: Int = 3,
        asOf: Date = Date(timeIntervalSince1970: 1_700_000_000)
    ) -> SummarySnapshot {
        SummarySnapshot(calmMinutes: calm, overMinutes: over, streak: streak, asOf: asOf)
    }

    private func decode(_ url: URL) throws -> SummarySnapshot {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(SummarySnapshot.self, from: data)
    }

    func testWriteSnapshotRoundTripsEqualValue() throws {
        let url = tempDir.appendingPathComponent("summary.json")
        let snapshot = makeSnapshot()

        let ok = SummaryWriter.writeSnapshot(snapshot, to: url)

        XCTAssertTrue(ok)
        let decoded = try decode(url)
        XCTAssertEqual(decoded, snapshot)
    }

    func testWriteSnapshotOverwriteReplacesPriorContents() throws {
        let url = tempDir.appendingPathComponent("summary.json")
        let first = makeSnapshot(calm: 1, over: 0, streak: 1)
        let second = makeSnapshot(calm: 99, over: 5, streak: 7)

        XCTAssertTrue(SummaryWriter.writeSnapshot(first, to: url))
        XCTAssertTrue(SummaryWriter.writeSnapshot(second, to: url))

        let decoded = try decode(url)
        XCTAssertEqual(decoded, second)
    }

    func testWriteSnapshotReturnsFalseWhenWriteClosureThrows() throws {
        let url = tempDir.appendingPathComponent("summary.json")
        let snapshot = makeSnapshot()

        struct StubbedError: Error {}
        let ok = SummaryWriter.writeSnapshot(snapshot, to: url) { _, _ in
            throw StubbedError()
        }

        XCTAssertFalse(ok)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path),
                       "no partial file should exist when the write closure throws")
    }

    func testWriteSnapshotDoesNotLeavePartialFileWhenPriorWriteSucceededAndNextThrows() throws {
        let url = tempDir.appendingPathComponent("summary.json")
        let first = makeSnapshot(calm: 4, over: 0, streak: 2)
        XCTAssertTrue(SummaryWriter.writeSnapshot(first, to: url))

        struct StubbedError: Error {}
        let second = makeSnapshot(calm: 50, over: 50, streak: 50)
        let ok = SummaryWriter.writeSnapshot(second, to: url) { _, _ in
            throw StubbedError()
        }

        XCTAssertFalse(ok)
        // Prior file is unchanged because the stubbed write closure never touched disk.
        let decoded = try decode(url)
        XCTAssertEqual(decoded, first)
    }

    func testSharedConstantsMatchSpec() {
        XCTAssertEqual(SummaryWriter.bgTaskIdentifier, "com.pseudocowboy.mochi.summary.refresh")
        XCTAssertEqual(SummaryWriter.defaultsKey, "summaryBackgroundEnabled")
        XCTAssertEqual(SummaryWriter.appGroupID, "group.com.pseudocowboy.mochi")
        XCTAssertEqual(SummaryWriter.summaryFileName, "summary.json")
    }
}
