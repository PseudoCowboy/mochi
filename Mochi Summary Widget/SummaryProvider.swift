import WidgetKit
import SwiftUI

struct SummaryEntry: TimelineEntry {
    let date: Date
    let snapshot: SummarySnapshot
}

struct SummaryProvider: TimelineProvider {
    func placeholder(in context: Context) -> SummaryEntry {
        SummaryEntry(date: Date(), snapshot: SummarySnapshot(calmMinutes: 45, overMinutes: 12, streak: 7, asOf: Date()))
    }

    func getSnapshot(in context: Context, completion: @escaping (SummaryEntry) -> Void) {
        let fallbackSnapshot = context.isPreview ? SummarySnapshot(calmMinutes: 45, overMinutes: 12, streak: 7, asOf: Date()) : SummarySnapshot(calmMinutes: 0, overMinutes: 0, streak: 0, asOf: Date())
        let snapshot = fetchSnapshot() ?? fallbackSnapshot
        let entry = SummaryEntry(date: Date(), snapshot: snapshot)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SummaryEntry>) -> Void) {
        let snapshot = fetchSnapshot() ?? SummarySnapshot(calmMinutes: 0, overMinutes: 0, streak: 0, asOf: Date())
        let entry = SummaryEntry(date: Date(), snapshot: snapshot)
        
        let refreshDate = Date().addingTimeInterval(15 * 60)
        let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
        completion(timeline)
    }
    
    private func fetchSnapshot() -> SummarySnapshot? {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.pseudocowboy.mochi") else {
            return nil
        }
        
        let fileURL = containerURL.appendingPathComponent("summary.json")
        
        guard let data = try? Data(contentsOf: fileURL) else {
            return nil
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try? decoder.decode(SummarySnapshot.self, from: data)
    }
}
