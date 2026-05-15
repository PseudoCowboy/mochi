import SwiftUI

struct StressHistoryRow: View {
    let sample: StressSample
    
    var body: some View {
        HStack(spacing: 16) {
            Text(emoji(for: sample.state))
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("\(sample.bpm) bpm")
                    .font(.headline)
                
                Text(formattedDate(sample.date))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func emoji(for state: StressState) -> String {
        switch state {
        case .calm: return "😌"
        case .okay: return "🙂"
        case .stressed: return "😰"
        case .over: return "🥵"
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return date.formatted(date: .omitted, time: .shortened)
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday, " + date.formatted(date: .omitted, time: .shortened)
        } else {
            return date.formatted(date: .abbreviated, time: .shortened)
        }
    }
}