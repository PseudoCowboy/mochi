import XCTest
import SnapshotTesting
import SwiftUI
@testable import Mochi_iOS

final class StressHistoryChartViewSnapshotTests: XCTestCase {
    private let isRecording = false

    func testChartView_Empty() {
        let view = StressHistoryChartView(samples: [])
        assertSnapshot(
            of: view,
            as: .image(layout: .device(config: .iPhone13)),
            named: "empty",
            record: isRecording
        )
    }

    func testChartView_PartialDay() {
        let anchor = Date(timeIntervalSince1970: 1_700_000_000)
        let samples: [StressSample] = [
            StressSample(date: anchor.addingTimeInterval(3600 * 1), bpm: 70, state: .calm),
            StressSample(date: anchor.addingTimeInterval(3600 * 2), bpm: 120, state: .stressed),
            StressSample(date: anchor.addingTimeInterval(3600 * 3), bpm: 80, state: .calm)
        ]
        let view = StressHistoryChartView(samples: samples)
        assertSnapshot(
            of: view,
            as: .image(layout: .device(config: .iPhone13)),
            named: "partialDay",
            record: isRecording
        )
    }

    func testChartView_FullDay() {
        let anchor = Date(timeIntervalSince1970: 1_700_000_000)
        var samples: [StressSample] = []
        for hour in 0..<24 {
            let state: StressState = hour % 5 == 0 ? .over : (hour % 3 == 0 ? .stressed : .calm)
            let bpm = state == .calm ? 65 : (state == .stressed ? 110 : 150)
            samples.append(StressSample(date: anchor.addingTimeInterval(Double(hour * 3600)), bpm: bpm, state: state))
        }
        let view = StressHistoryChartView(samples: samples)
        assertSnapshot(
            of: view,
            as: .image(layout: .device(config: .iPhone13)),
            named: "full24h",
            record: isRecording
        )
    }
}
