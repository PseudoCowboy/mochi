import SwiftUI
import Charts

struct StressHistoryChartView: View {
    let samples: [StressSample]
    
    private var sortedSamples: [StressSample] {
        samples.sorted { $0.date < $1.date }
    }
    
    var body: some View {
        Chart {
            ForEach(sortedSamples) { sample in
                LineMark(
                    x: .value("Time", sample.date),
                    y: .value("BPM", sample.bpm)
                )
                
                PointMark(
                    x: .value("Time", sample.date),
                    y: .value("BPM", sample.bpm)
                )
                .foregroundStyle(color(for: sample.state))
            }
        }
        .frame(height: 220)
    }
    
    private func color(for state: StressState) -> Color {
        switch state {
        case .calm: return .green
        case .okay, .stressed: return .orange
        case .over: return .red
        }
    }
}
