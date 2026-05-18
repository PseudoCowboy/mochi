import SwiftUI
import SwiftData

struct SummaryView: View {
    @Environment(\.modelContext) private var modelContext
    
    @State private var calmMinutes: Int = 0
    @State private var overMinutes: Int = 0
    @State private var streak: Int = 0
    
    var body: some View {
        VStack(spacing: 8) {
            Text("TODAY")
                .font(.caption)
                .foregroundColor(.secondary)
                .fontWeight(.bold)
            
            HStack(spacing: 16) {
                metricView(value: calmMinutes, label: "Calm", color: .calm)
                metricView(value: overMinutes, label: "Over", color: .over)
            }
            
            if streak >= 2 {
                streakBadge
            }
        }
        .task {
            let reader = StressHistoryReader(context: modelContext)
            let calm = (try? reader.calmMinutesToday(now: .now)) ?? 0
            let over = (try? reader.overMinutesToday(now: .now)) ?? 0
            
            calmMinutes = calm
            overMinutes = over
            
            DailySummaryStore.save(DailySummary(calm: calm, over: over), on: .now)
            streak = DailySummaryStore.currentStreak(asOf: .now, todayCalm: calm, todayOver: over)
        }
    }
    
    private func metricView(value: Int, label: String, color: Color) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(value)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(color)
                
                Text("min")
                    .font(.caption2)
                    .foregroundColor(color)
            }
            
            Text(label)
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }
    
    private var streakBadge: some View {
        HStack(spacing: 4) {
            Text("🔥 \(streak) day streak")
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundColor(.stressed)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.stressed.opacity(0.2))
        )
        .padding(.top, 4)
    }
}
