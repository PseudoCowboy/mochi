import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            PetGlanceView()
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        NavigationLink(destination: SettingsView()) {
                            Image(systemName: "gear")
                        }
                        .accessibilityLabel("Settings")
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink(destination: SummaryView()) {
                            Image(systemName: "chart.bar.fill")
                        }
                        .accessibilityLabel("Daily Summary")
                    }
                }
        }
    }
}

#Preview {
    ContentView()
        .environment(PetViewModel())
}
