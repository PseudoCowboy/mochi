import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            PetGlanceView()
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink(destination: SettingsView()) {
                            Image(systemName: "gear")
                        }
                    }
                }
        }
    }
}

#Preview {
    ContentView()
        .environment(PetViewModel())
}
