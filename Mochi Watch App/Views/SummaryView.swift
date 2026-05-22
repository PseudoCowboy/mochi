import SwiftUI
import SwiftData

struct SummaryView: View {
    @Environment(\.modelContext) private var modelContext
    var now: Date
    
    @State private var calmMinutes: Int
    @State private var overMinutes: Int
    @State private var streak: Int
    
    @State private var selectedTab: Int = 0 // 0 for 24H, 1 for Week
    
    init(now: Date = .now, calmMinutes: Int = 0, overMinutes: Int = 0, streak: Int = 0) {
        self.now = now
        self._calmMinutes = State(initialValue: calmMinutes)
        self._overMinutes = State(initialValue: overMinutes)
        self._streak = State(initialValue: streak)
    }
    
    let hourlyData: [Double] = [
        0.1, 0.1, 0.1, 0.1, 0.1, 0.2, // 0-5
        0.3, 0.5, 0.6, 0.7, 0.8, 0.7, // 6-11
        0.6, 0.7, 0.8, 0.9, 0.8, 0.7, // 12-17
        0.6, 0.5, 0.4, 0.3, 0.2, 0.1  // 18-23
    ]
    
    let dailyData: [Double] = [0.4, 0.5, 0.6, 0.5, 0.7, 0.3, 0.2]
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 0) {
                Text("24H")
                    .font(.caption2)
                    .fontWeight(selectedTab == 0 ? .bold : .regular)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .background(selectedTab == 0 ? Color.white.opacity(0.2) : Color.clear)
                    .cornerRadius(4)
                    .onTapGesture { selectedTab = 0 }
                
                Text("Week")
                    .font(.caption2)
                    .fontWeight(selectedTab == 1 ? .bold : .regular)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .background(selectedTab == 1 ? Color.white.opacity(0.2) : Color.clear)
                    .cornerRadius(4)
                    .onTapGesture { selectedTab = 1 }
            }
            .padding(2)
            .background(Color.white.opacity(0.1))
            .cornerRadius(6)
            .frame(height: 28)
            
            Text(selectedTab == 0 ? "Stress · 24H" : "Stress · Week")
                .font(.caption2)
                .foregroundColor(.secondary)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            GeometryReader { geo in
                HStack(alignment: .bottom, spacing: selectedTab == 0 ? 2 : 8) {
                    let data = selectedTab == 0 ? hourlyData : dailyData
                    ForEach(data.indices, id: \.self) { index in
                        let value = data[index]
                        RoundedRectangle(cornerRadius: 2)
                            .fill(colorForValue(value))
                            .frame(height: max(geo.size.height * CGFloat(value), 4))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .bottom)
            }
            .frame(height: 50)
            
            HStack {
                if selectedTab == 0 {
                    Text("0").frame(maxWidth: .infinity, alignment: .leading)
                    Text("6").frame(maxWidth: .infinity, alignment: .center)
                    Text("12").frame(maxWidth: .infinity, alignment: .center)
                    Text("18").frame(maxWidth: .infinity, alignment: .trailing)
                } else {
                    let days = ["M", "T", "W", "T", "F", "S", "S"]
                    ForEach(days.indices, id: \.self) { index in
                        Text(days[index]).frame(maxWidth: .infinity)
                    }
                }
            }
            .font(.system(size: 10))
            .foregroundColor(.secondary)
            
            Text(selectedTab == 0 ? "Peak: 90 at 3pm" : "Peak: 70 on Friday")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 4)
        .task {
            let reader = StressHistoryReader(context: modelContext)
            let calm = (try? reader.calmMinutesToday(now: now)) ?? 0
            let over = (try? reader.overMinutesToday(now: now)) ?? 0
            
            calmMinutes = calm
            overMinutes = over
            
            DailySummaryStore.save(DailySummary(calm: calm, over: over), on: now)
            streak = DailySummaryStore.currentStreak(asOf: now, todayCalm: calm, todayOver: over)
        }
    }
    
    private func colorForValue(_ value: Double) -> Color {
        if value < 0.33 { return .calm }
        else if value < 0.66 { return .okay }
        else if value < 0.85 { return .stressed }
        else { return .over }
    }
}
