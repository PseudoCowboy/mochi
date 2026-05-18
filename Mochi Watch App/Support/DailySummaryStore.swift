import Foundation

struct DailySummary: Codable {
    let calm: Int
    let over: Int
}

enum DailySummaryStore {
    private static let appGroupIdentifier = "group.com.pseudocowboy.mochi"
    private static let snapshotFileName = "summary.json"

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func key(for day: Date) -> String {
        return "mochi.summary.\(formatter.string(from: day))"
    }

    static func save(_ summary: DailySummary, on day: Date) {
        if let data = try? JSONEncoder().encode(summary) {
            UserDefaults.standard.set(data, forKey: key(for: day))
        }
        writeSnapshot(summary, on: day)
    }

    private static func writeSnapshot(_ summary: DailySummary, on day: Date) {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else {
            NSLog("DailySummaryStore: App Group container unavailable for \(appGroupIdentifier)")
            return
        }

        let streak = currentStreak(asOf: day, todayCalm: summary.calm, todayOver: summary.over)
        let snapshot = SummarySnapshot(
            calmMinutes: summary.calm,
            overMinutes: summary.over,
            streak: streak,
            asOf: day
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        do {
            let data = try encoder.encode(snapshot)
            let fileURL = containerURL.appendingPathComponent(snapshotFileName)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            NSLog("DailySummaryStore: failed to write summary.json: \(error)")
        }
    }

    static func load(_ day: Date) -> DailySummary? {
        guard let data = UserDefaults.standard.data(forKey: key(for: day)),
              let summary = try? JSONDecoder().decode(DailySummary.self, from: data) else {
            return nil
        }
        return summary
    }

    static func currentStreak(asOf now: Date, todayCalm: Int, todayOver: Int) -> Int {
        var streak = 0
        if todayCalm >= todayOver && todayCalm > 0 {
            streak += 1
        }
        
        let calendar = Calendar.current
        var dateIterator = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now)) ?? now.addingTimeInterval(-86400)
        
        while let summary = load(dateIterator) {
            if summary.calm >= summary.over && summary.calm > 0 {
                streak += 1
                dateIterator = calendar.date(byAdding: .day, value: -1, to: dateIterator) ?? dateIterator.addingTimeInterval(-86400)
            } else {
                break
            }
        }
        
        return streak
    }
}