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
        save(summary, on: day, defaults: .standard)
    }

    static func save(_ summary: DailySummary, on day: Date, defaults: UserDefaults) {
        if let data = try? JSONEncoder().encode(summary) {
            defaults.set(data, forKey: key(for: day))
        }
    }

    static func load(_ day: Date) -> DailySummary? {
        load(day, defaults: .standard)
    }

    static func load(_ day: Date, defaults: UserDefaults) -> DailySummary? {
        guard let data = defaults.data(forKey: key(for: day)),
              let summary = try? JSONDecoder().decode(DailySummary.self, from: data) else {
            return nil
        }
        return summary
    }

    static func currentStreak(asOf now: Date, todayCalm: Int, todayOver: Int) -> Int {
        currentStreak(asOf: now, todayCalm: todayCalm, todayOver: todayOver, defaults: .standard)
    }

    static func currentStreak(
        asOf now: Date,
        todayCalm: Int,
        todayOver: Int,
        defaults: UserDefaults
    ) -> Int {
        var streak = 0
        if todayCalm >= todayOver && todayCalm > 0 {
            streak += 1
        }

        let calendar = Calendar.current
        var dateIterator = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now)) ?? now.addingTimeInterval(-86400)

        while let summary = load(dateIterator, defaults: defaults) {
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
