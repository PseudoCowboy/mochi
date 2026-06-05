import SwiftUI
import SwiftData
import BackgroundTasks

@main
struct MochiIOSApp: App {
    let container: ModelContainer
    @Environment(\.scenePhase) private var scenePhase
    @State private var didActivateOnce = false

    init() {
        do {
            container = try StressHistoryReader.makeSharedContainer()
        } catch {
            fatalError("Failed to create shared container: \(error)")
        }
        SummaryWriter.register(BGTaskScheduler.shared)
        // Receive real watch-measured data over WatchConnectivity and fold it
        // into the iPhone's App-Group store (App Groups don't cross devices).
        PhoneSyncReceiver.shared.activate(container: container)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onChange(of: scenePhase) { _, newPhase in
                    guard newPhase == .active, !didActivateOnce else { return }
                    didActivateOnce = true
                    let enabled = (UserDefaults.standard.object(forKey: SummaryWriter.defaultsKey) as? Bool) ?? true
                    guard enabled else { return }
                    SummaryWriter.scheduleNext()
                }
                .task {
                    // Re-arm the daily breathe reminder if the user opted in.
                    if CalmReminderScheduler.isEnabled {
                        await CalmReminderScheduler.reschedule()
                    }
                }
        }
        .modelContainer(container)
    }
}
