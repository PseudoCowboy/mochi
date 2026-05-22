import XCTest
import SnapshotTesting
import SwiftUI
import WidgetKit
@testable import Mochi_Summary_Widget

final class SummaryWidgetSnapshotTests: XCTestCase {
    private let isRecording = false

    func testWidget_SystemSmall() {
        let entry = SummaryEntry(
            date: Date(timeIntervalSince1970: 1_700_000_000),
            snapshot: SummarySnapshot(calmMinutes: 45, overMinutes: 10, streak: 3, asOf: Date(timeIntervalSince1970: 1_700_000_000))
        )
        let view = SummaryWidgetView(entry: entry)
            .environment(\.widgetFamily, .systemSmall)
            
        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 170, height: 170)),
            named: "systemSmall",
            record: isRecording
        )
    }

    func testWidget_SystemMedium() {
        let entry = SummaryEntry(
            date: Date(timeIntervalSince1970: 1_700_000_000),
            snapshot: SummarySnapshot(calmMinutes: 45, overMinutes: 10, streak: 3, asOf: Date(timeIntervalSince1970: 1_700_000_000))
        )
        let view = SummaryWidgetView(entry: entry)
            .environment(\.widgetFamily, .systemMedium)
            
        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 364, height: 170)),
            named: "systemMedium",
            record: isRecording
        )
    }
}
