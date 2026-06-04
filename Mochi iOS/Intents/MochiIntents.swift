import AppIntents
import SwiftData
import WidgetKit
import Foundation

// MARK: - Check my stress

/// "Check my stress now" — Siri/Shortcuts/Spotlight read-out of the latest state
/// plus today's calm progress. Does not need to open the app.
struct CheckStressIntent: AppIntent {
    static var title: LocalizedStringResource = "Check My Stress"
    static var description = IntentDescription("Ask mochi how stressed you are right now.")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let snapshot = SummaryStore.read()
        let latest = CheckInWriter.latestState()
        let goal = DailyGoal.minutes
        let calm = snapshot?.calmMinutes ?? 0

        let stateText: String
        if let latest {
            stateText = "You're \(latest.label.lowercased()) right now."
        } else {
            stateText = "I don't have a recent reading — wear your Apple Watch to track stress."
        }

        let progressText: String
        if calm >= goal, goal > 0 {
            progressText = "You've hit your \(goal)-minute calm goal today — a perfect day! 🌤️"
        } else {
            progressText = "You've banked \(calm) of \(goal) calm minutes today."
        }

        return .result(dialog: IntentDialog("\(stateText) \(progressText)"))
    }
}

// MARK: - Start a breath session

/// "Start a breath session" — opens mochi and presents the guided breathing flow.
struct StartBreathIntent: AppIntent {
    static var title: LocalizedStringResource = "Start a Breath Session"
    static var description = IntentDescription("Open mochi and begin a guided breathing session.")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        MochiAppState.shared.requestBreathSession()
        return .result(dialog: IntentDialog("Let's breathe together. 深呼吸~"))
    }
}

// MARK: - Log a calm check-in

/// "Log a calm check-in" — records a manual calm moment so it counts toward the
/// daily goal and streak even without a watch reading.
struct LogCalmCheckInIntent: AppIntent {
    static var title: LocalizedStringResource = "Log a Calm Check-In"
    static var description = IntentDescription("Tell mochi you're feeling calm right now.")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let ok = CheckInWriter.logCalmCheckIn()
        MochiAppState.shared.notifyDataChanged()
        let dialog = ok
            ? IntentDialog("Logged a calm moment. Nicely done — keep it up. ✨")
            : IntentDialog("I couldn't save that just now. Try again in a moment.")
        return .result(dialog: dialog)
    }
}

// MARK: - Shortcuts surface (Siri / Spotlight / Action Button)

struct MochiShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CheckStressIntent(),
            phrases: [
                "Check my stress in \(.applicationName)",
                "How stressed am I in \(.applicationName)",
                "\(.applicationName) stress check"
            ],
            shortTitle: "Check Stress",
            systemImageName: "waveform.path.ecg"
        )
        AppShortcut(
            intent: StartBreathIntent(),
            phrases: [
                "Start a breath session in \(.applicationName)",
                "Breathe with \(.applicationName)",
                "Start breathing in \(.applicationName)"
            ],
            shortTitle: "Breathe",
            systemImageName: "wind"
        )
        AppShortcut(
            intent: LogCalmCheckInIntent(),
            phrases: [
                "Log a calm check-in in \(.applicationName)",
                "I'm feeling calm in \(.applicationName)",
                "\(.applicationName) calm check-in"
            ],
            shortTitle: "Calm Check-In",
            systemImageName: "leaf"
        )
    }
}

// MARK: - SwiftData helpers for intents

/// Reads the latest state and writes manual calm check-ins into the shared store.
enum CheckInWriter {
    @MainActor
    static func latestState() -> StressState? {
        guard let container = try? StressHistoryReader.makeSharedContainer() else { return nil }
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<StressSample>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        descriptor.includePendingChanges = true
        return (try? context.fetch(descriptor))?.first?.state
    }

    /// Inserts a calm-state sample at "now" so manual check-ins count toward goals.
    @MainActor
    @discardableResult
    static func logCalmCheckIn(now: Date = .now) -> Bool {
        guard let container = try? StressHistoryReader.makeSharedContainer() else { return false }
        let context = ModelContext(container)
        let sample = StressSample(date: now, bpm: 70, state: .calm)
        context.insert(sample)
        do {
            try context.save()
        } catch {
            print("[CheckInWriter] save failed: \(error)")
            return false
        }
        // Keep the shared snapshot (and therefore the widget + Siri read-outs)
        // in step with the freshly logged calm minute.
        Task { @MainActor in
            await SummaryWriter.writeSnapshot()
            WidgetCenter.shared.reloadAllTimelines()
        }
        return true
    }
}
