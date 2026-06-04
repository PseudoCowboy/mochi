import SwiftUI

/// "Perfect Day" progress ring for the daily calm-minutes goal. Fills blue→amber
/// and shows a celebratory golden state once the goal is met.
struct GoalRingView: View {
    let calmMinutes: Int
    let goalMinutes: Int
    var diameter: CGFloat = 168

    private var progress: Double {
        guard goalMinutes > 0 else { return 0 }
        return min(1, Double(calmMinutes) / Double(goalMinutes))
    }

    private var met: Bool { goalMinutes > 0 && calmMinutes >= goalMinutes }

    private var ringGradient: AngularGradient {
        AngularGradient(
            colors: met
                ? [.okay, .calm, .okay]
                : [.calm, Color(red: 0.45, green: 0.75, blue: 0.95)],
            center: .center
        )
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.calm.opacity(0.15), lineWidth: 16)

            Circle()
                .trim(from: 0, to: max(0.001, progress))
                .stroke(ringGradient, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: (met ? Color.okay : Color.calm).opacity(0.4), radius: met ? 10 : 4)
                .animation(.easeOut(duration: 0.6), value: progress)

            VStack(spacing: 2) {
                if met {
                    Text("🌤️")
                        .font(.system(size: 34))
                    Text("Perfect Day")
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(Color.okay)
                } else {
                    Text("\(calmMinutes)")
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.ink)
                        .contentTransition(.numericText())
                    Text("of \(goalMinutes) calm min")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Color.muted)
                }
            }
        }
        .frame(width: diameter, height: diameter)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Daily calm goal")
        .accessibilityValue(met
            ? "Perfect day, goal of \(goalMinutes) minutes met"
            : "\(calmMinutes) of \(goalMinutes) calm minutes")
    }
}
