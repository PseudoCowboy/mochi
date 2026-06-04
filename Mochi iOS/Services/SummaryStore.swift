import Foundation

/// Reads the shared `summary.json` snapshot written by `SummaryWriter`. Used by
/// the dashboard and App Intents for a fast, watch-independent read of today's
/// calm/over minutes and streak without touching SwiftData.
enum SummaryStore {
    static let appGroupID = "group.com.pseudocowboy.mochi"
    static let fileName = "summary.json"

    static func read() -> SummarySnapshot? {
        guard let url = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent(fileName),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(SummarySnapshot.self, from: data)
    }
}
