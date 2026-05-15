import SwiftUI
import SwiftData

struct ContentView: View {
    @Query private var samples: [StressSample]
    
    init() {
        let twentyFourHoursAgo = Calendar.current.date(byAdding: .hour, value: -24, to: Date()) ?? Date()
        _samples = Query(
            filter: #Predicate<StressSample> { $0.date >= twentyFourHoursAgo },
            sort: \.date,
            order: .reverse
        )
    }
    
    var body: some View {
        NavigationStack {
            if samples.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "heart.text.square")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("No stress samples yet")
                        .font(.headline)
                    
                    Text("Wear your Apple Watch to start tracking.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            } else {
                List(samples) { sample in
                    StressHistoryRow(sample: sample)
                }
                .listStyle(.plain)
                .navigationTitle("Last 24 Hours")
            }
        }
    }
}