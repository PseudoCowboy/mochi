import SwiftUI
import UserNotifications

/// iOS settings: daily calm goal, breathe reminders, and background updates.
struct IOSSettingsView: View {
    @AppStorage("summaryBackgroundEnabled") private var bgEnabled: Bool = true

    @State private var goalMinutes: Int = DailyGoal.minutes
    @State private var remindersOn: Bool = CalmReminderScheduler.isEnabled
    @State private var reminderTime: Date = CalmReminderScheduler.reminderDate
    @State private var authDenied: Bool = false

    var body: some View {
        Form {
            Section {
                Stepper(value: $goalMinutes, in: DailyGoal.minMinutes...DailyGoal.maxMinutes, step: 5) {
                    HStack {
                        Label("Daily calm goal", systemImage: "target")
                        Spacer()
                        Text("\(goalMinutes) min")
                            .foregroundStyle(Color.calm)
                            .fontWeight(.semibold)
                    }
                }
                .onChange(of: goalMinutes) { _, newValue in
                    DailyGoal.minutes = newValue
                }
            } header: {
                Text("Perfect Day")
            } footer: {
                Text("Reach this many calm minutes in a day to earn a Perfect Day.")
            }

            Section {
                Toggle(isOn: $remindersOn) {
                    Label("Breathe reminders", systemImage: "bell.badge")
                }
                .tint(.calm)
                .onChange(of: remindersOn) { _, newValue in
                    Task { await updateReminders(enabled: newValue) }
                }

                if remindersOn {
                    DatePicker(
                        "Reminder time",
                        selection: $reminderTime,
                        displayedComponents: .hourAndMinute
                    )
                    .onChange(of: reminderTime) { _, _ in
                        Task { await updateReminders(enabled: true) }
                    }
                }

                if authDenied {
                    Text("Notifications are turned off for mochi. Enable them in Settings to get reminders.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Reminders")
            } footer: {
                Text("A gentle daily nudge to take a breathing break with mochi.")
            }

            Section {
                Toggle(isOn: $bgEnabled) {
                    Label("Background updates", systemImage: "arrow.clockwise")
                }
                .tint(.calm)
                .onChange(of: bgEnabled) { _, newValue in
                    if newValue {
                        SummaryWriter.scheduleNext()
                    } else {
                        SummaryWriter.cancelScheduled()
                    }
                }
            } header: {
                Text("Sync")
            } footer: {
                Text("Refresh your calm summary in the background every ~15 minutes.")
            }
        }
        .navigationTitle("Settings")
        .task {
            let status = await CalmReminderScheduler.authorizationStatus()
            authDenied = (status == .denied)
        }
    }

    private func updateReminders(enabled: Bool) async {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        let hour = comps.hour ?? 20
        let minute = comps.minute ?? 0
        if enabled {
            let ok = await CalmReminderScheduler.enable(hour: hour, minute: minute)
            if !ok {
                remindersOn = false
                authDenied = true
            }
        } else {
            await CalmReminderScheduler.disable()
        }
    }
}
