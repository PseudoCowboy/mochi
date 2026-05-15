import SwiftUI
import SwiftData

@main
struct MochiIOSApp: App {
    let container: ModelContainer
    
    init() {
        do {
            container = try StressHistoryReader.makeSharedContainer()
        } catch {
            fatalError("Failed to create shared container: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}