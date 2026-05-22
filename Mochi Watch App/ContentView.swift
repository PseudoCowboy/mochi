import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            PetGlanceView()
            SummaryView()
            SettingsView()
        }
        .tabViewStyle(.verticalPage)
    }
}

#Preview {
    ContentView()
        .environment(PetViewModel())
}
