import Foundation

/// Per-day calm/over minute tallies persisted to the shared App Group so the iOS
/// app can compute a real calm-day streak across launches. Mirrors the watch's
/// `DailySummaryStore` but is App-Group scoped (the watch's lives in `.standard`).
enum DailyMinutesStore {
    static let appGroupID = "group.com.pseudocowboy.mochi"

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    private static func key(for day: Date) -> String {
        "mochi.ios.minutes.\(formatter.string(from: day))"
    }

    static func save(calm: Int, over: Int, on day: Date, calendar: Calendar = .current) {
        let dayStart = calendar.startOfDay(for: day)
        let payload = ["calm": calm, "over": over]
        defaults.set(payload, forKey: key(for: dayStart))
    }

    static func load(_ day: Date, calendar: Calendar = .current) -> (calm: Int, over: Int)? {
        let dayStart = calendar.startOfDay(for: day)
        guard let raw = defaults.dictionary(forKey: key(for: dayStart)) as? [String: Int],
              let calm = raw["calm"], let over = raw["over"] else {
            return nil
        }
        return (calm, over)
    }

    /// A day counts toward the streak when calm minutes are positive and meet or
    /// exceed over minutes. Counts today (if qualifying) then walks backwards.
    static func currentStreak(asOf now: Date, calendar: Calendar = .current) -> Int {
        var streak = 0
        var cursor = calendar.startOfDay(for: now)

        // Today only counts if it currently qualifies, but a non-qualifying today
        // shouldn't break a prior streak — skip to yesterday in that case.
        if let today = load(cursor, calendar: calendar), qualifies(today) {
            streak += 1
        }
        cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor

        while let day = load(cursor, calendar: calendar), qualifies(day) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }

    private static func qualifies(_ day: (calm: Int, over: Int)) -> Bool {
        day.calm > 0 && day.calm >= day.over
    }
}
