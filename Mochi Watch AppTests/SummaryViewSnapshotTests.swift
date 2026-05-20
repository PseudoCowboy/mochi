import XCTest
import SnapshotTesting
import SwiftUI
@testable import Mochi_Watch_App

final class SummaryViewSnapshotTests: XCTestCase {
    private let isRecording = false

    func testSummaryView_41mm() {
        let view = SummaryView(
            now: Date(timeIntervalSince1970: 1_700_000_000),
            calmMinutes: 45,
            overMinutes: 10,
            streak: 3
        )
        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 176, height: 215)),
            named: "41mm",
            record: isRecording
        )
    }

    func testSummaryView_45mm() {
        let view = SummaryView(
            now: Date(timeIntervalSince1970: 1_700_000_000),
            calmMinutes: 45,
            overMinutes: 10,
            streak: 3
        )
        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 198, height: 242)),
            named: "45mm",
            record: isRecording
        )
    }
}
