import SwiftUI
import Charts

/// Last-7-days calm-minutes trend. Bars are calm minutes; the goal shows as a
/// dashed rule so the user can see which days were "perfect".
struct WeeklyTrendChart: View {
    let trend: [DayInsight]
    let goalMinutes: Int

    private let weekdayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEEE" // single-letter weekday
        return f
    }()

    private var maxValue: Int {
        max(goalMinutes, trend.map(\.calmMinutes).max() ?? 0, 10)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("This Week")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(Color.ink)

            Chart {
                ForEach(trend) { day in
                    BarMark(
                        x: .value("Day", day.date, unit: .day),
                        y: .value("Calm minutes", day.calmMinutes),
                        width: .ratio(0.6)
                    )
                    .foregroundStyle(
                        day.calmMinutes >= goalMinutes
                            ? Color.okay.gradient
                            : Color.calm.gradient
                    )
                    .cornerRadius(5)
                }

                if goalMinutes > 0 {
                    RuleMark(y: .value("Goal", goalMinutes))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .foregroundStyle(Color.muted.opacity(0.6))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("goal \(goalMinutes)m")
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(Color.muted)
                        }
                }
            }
            .chartYScale(domain: 0...Int(Double(maxValue) * 1.15))
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(weekdayFormatter.string(from: date))
                                .font(.system(.caption2, design: .rounded))
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .frame(height: 150)
        }
    }
}
