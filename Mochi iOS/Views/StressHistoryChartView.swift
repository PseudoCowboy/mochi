import SwiftUI
import Charts

struct StressHistoryChartView: View {
    let samples: [StressSample]
    
    private var sortedSamples: [StressSample] {
        samples.sorted { $0.date < $1.date }
    }
    
    @ViewBuilder
    var body: some View {
        if samples.isEmpty {
            EmptyView()
        } else {
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
    }
    
    private func color(for state: StressState) -> Color {
        switch state {
        case .calm: return .green
        case .okay, .stressed: return .orange
        case .over: return .red
        }
    }
}
