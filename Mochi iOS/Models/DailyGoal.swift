import Foundation

/// The user's daily "calm minutes" goal — mochi's take on Grow's "Perfect Day".
/// Hitting the goal earns a celebratory state in the app and widget. The goal is
/// stored in the shared App Group so the app, widget, and App Intents agree.
enum DailyGoal {
    static let appGroupID = "group.com.pseudocowboy.mochi"
    static let defaultMinutes = 30
    static let minMinutes = 5
    static let maxMinutes = 120
    private static let key = "mochi.dailyGoalMinutes"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    /// Current goal in minutes. Falls back to `defaultMinutes` when unset.
    static var minutes: Int {
        get {
            let raw = defaults.object(forKey: key) as? Int
            guard let raw else { return defaultMinutes }
            return clamp(raw)
        }
        set { defaults.set(clamp(newValue), forKey: key) }
    }

    static func clamp(_ value: Int) -> Int {
        min(maxMinutes, max(minMinutes, value))
    }

    /// Whether the supplied calm minutes complete today's goal.
    static func isMet(calmMinutes: Int, goal: Int = minutes) -> Bool {
        goal > 0 && calmMinutes >= goal
    }
}
