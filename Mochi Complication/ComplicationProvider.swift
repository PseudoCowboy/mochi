import Foundation
import WidgetKit

struct StressPetEntry: TimelineEntry {
    let date: Date
    let state: StressState
    let bpm: Int
}

struct ComplicationProvider: TimelineProvider {
    typealias Entry = StressPetEntry

    func placeholder(in context: Context) -> StressPetEntry {
        StressPetEntry(date: .now, state: .calm, bpm: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (StressPetEntry) -> Void) {
        completion(ComplicationDataProvider.latest())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StressPetEntry>) -> Void) {
        let latest = ComplicationDataProvider.latest()
        let now = Date.now
        let stride: TimeInterval = 15 * 60
        var entries: [StressPetEntry] = []
        for i in 0..<6 {
            let date = now.addingTimeInterval(stride * Double(i))
            entries.append(StressPetEntry(date: date, state: latest.state, bpm: latest.bpm))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}
