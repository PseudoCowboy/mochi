import Foundation

struct DailySummary: Codable {
    let calm: Int
    let over: Int
}

enum DailySummaryStore {
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