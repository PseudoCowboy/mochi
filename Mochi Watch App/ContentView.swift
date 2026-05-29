import SwiftUI

struct ContentView: View {
    @State private var selection: Int = {
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "-mochiInitialTab"), i + 1 < args.count,
           let v = Int(args[i + 1]) {
            return v
        }
        return 0
    }()

    var body: some View {
        TabView(selection: $selection) {
            PetGlanceView().tag(0)
            SummaryView().tag(1)
            SettingsView().tag(2)
        }
        .tabViewStyle(.verticalPage)
    }
}

#Preview {
    ContentView()
        .environment(PetViewModel())
}
