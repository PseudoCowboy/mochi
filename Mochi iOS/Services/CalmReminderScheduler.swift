import Foundation
import UserNotifications

/// Opt-in daily "breathe" reminders via local notifications. Configurable hour/
/// minute, persisted to the shared App Group. Kept deliberately simple: one
/// repeating daily reminder, plus an optional second "afternoon reset".
enum CalmReminderScheduler {
    static let appGroupID = "group.com.pseudocowboy.mochi"
    static let enabledKey = "mochi.reminders.enabled"
    static let hourKey = "mochi.reminders.hour"
    static let minuteKey = "mochi.reminders.minute"
    static let categoryID = "mochi.reminder.breathe"
    private static let primaryID = "mochi.reminder.daily"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    // MARK: - Stored preferences

    static var isEnabled: Bool {
        get { defaults.bool(forKey: enabledKey) }
        set { defaults.set(newValue, forKey: enabledKey) }
    }

    /// Reminder time of day. Defaults to 20:00 (an evening wind-down).
    static var hour: Int {
        get { defaults.object(forKey: hourKey) as? Int ?? 20 }
        set { defaults.set(min(23, max(0, newValue)), forKey: hourKey) }
    }

    static var minute: Int {
        get { defaults.object(forKey: minuteKey) as? Int ?? 0 }
        set { defaults.set(min(59, max(0, newValue)), forKey: minuteKey) }
    }

    static var reminderDate: Date {
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        return Calendar.current.date(from: comps) ?? Date()
    }

    // MARK: - Authorization

    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            print("[CalmReminderScheduler] auth error: \(error)")
            return false
        }
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    // MARK: - Scheduling

    /// Enable reminders at the given time, requesting permission if needed.
    @discardableResult
    static func enable(hour: Int, minute: Int) async -> Bool {
        let granted = await requestAuthorization()
        guard granted else {
            isEnabled = false
            return false
        }
        self.hour = hour
        self.minute = minute
        isEnabled = true
        await reschedule()
        return true
    }

    static func disable() async {
        isEnabled = false
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [primaryID])
    }

    /// Rebuild the pending reminder from current preferences. No-op when disabled.
    static func reschedule() async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [primaryID])
        guard isEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "Time to breathe"
        content.body = "Take a minute with mochi to settle your stress. 深呼吸~"
        content.sound = .default
        content.categoryIdentifier = categoryID

        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(identifier: primaryID, content: content, trigger: trigger)
        do {
            try await center.add(request)
        } catch {
            print("[CalmReminderScheduler] schedule failed: \(error)")
        }
    }
}
