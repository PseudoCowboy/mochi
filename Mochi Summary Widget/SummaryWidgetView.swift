import WidgetKit
import SwiftUI

extension Color {
    static let widgetCalm = Color(red: 0.339, green: 0.821, blue: 0.637)
    static let widgetOkay = Color(red: 0.881, green: 0.763, blue: 0.293)
    static let widgetStressed = Color(red: 0.990, green: 0.548, blue: 0.272)
    static let widgetOver = Color(red: 0.953, green: 0.384, blue: 0.365)
}

struct SummaryWidgetView: View {
    var entry: SummaryEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        case .accessoryCircular:
            accessoryCircularView
        default:
            Text("Unsupported Family")
        }
    }

    private var smallView: some View {
        VStack(alignment: .center, spacing: 4) {
            Image(systemName: "flame.fill")
                .font(.title)
                .foregroundColor(.widgetStressed)
            Text("\(entry.snapshot.streak)")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundColor(.widgetStressed)
                .minimumScaleFactor(0.8)
            Text("day streak")
                .font(.caption)
                .foregroundColor(.secondary)
                .fontWeight(.medium)
        }
        .padding()
        .containerBackground(for: .widget) {
            Color(UIColor.systemBackground)
        }
    }

    private var mediumView: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("TODAY")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fontWeight(.bold)
                
                HStack(spacing: 24) {
                    metricView(value: entry.snapshot.calmMinutes, label: "Calm", color: .widgetCalm, size: 36)
                    metricView(value: entry.snapshot.overMinutes, label: "Over", color: .widgetOver, size: 36)
                }
                
                Spacer(minLength: 0)
                
                streakBadge
            }
            
            Spacer(minLength: 0)
        }
        .padding()
        .containerBackground(for: .widget) {
            Color(UIColor.systemBackground)
        }
    }
    
    private var accessoryCircularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Image(systemName: "flame.fill")
                    .font(.caption)
                Text("\(entry.snapshot.streak)")
                    .font(.system(.title2, design: .rounded, weight: .bold))
            }
            .widgetAccentable()
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private func metricView(value: Int, label: String, color: Color, size: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(value)")
                    .font(.system(size: size, weight: .bold, design: .rounded))
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
            Text("🔥 \(entry.snapshot.streak) day streak")
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundColor(.widgetStressed)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.widgetStressed.opacity(0.2))
        )
    }
}
