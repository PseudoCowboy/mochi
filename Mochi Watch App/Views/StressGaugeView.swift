import SwiftUI

/// Renders a 270° gauge, open at the bottom, to visualize a value
/// from calm to "over" stressed. The gauge includes a colorful gradient
/// arc, tick marks, and a moving indicator dot.
///
/// This view uses a `GeometryReader` to proportionally scale its rendering
/// based on the container's size, ensuring a clean and adaptive fit.
struct StressGaugeView: View {
    var progress: Double
    var lineWidth: CGFloat = 14
    var tickCount: Int = 12

    private let startAngle = Angle.degrees(135)
    private let endAngle = Angle.degrees(405)

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let radius = (size / 2) - (lineWidth / 2)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)

            ZStack {
                // A faint background track for the full 270° arc.
                Path { path in
                    path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
                }
                .stroke(Color.white.opacity(0.08), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                
                // The main gradient arc.
                Path { path in
                    path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
                }
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [.calm, .okay, .stressed, .over]),
                        center: .center,
                        startAngle: startAngle,
                        endAngle: endAngle
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )

                // The indicator dot that moves with `progress`.
                indicatorDot(radius: radius, computedLineWidth: lineWidth)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func indicatorDot(radius: CGFloat, computedLineWidth: CGFloat) -> some View {
        let clampedProgress = progress.clamp(to: 0...1)
        let arcAngle = endAngle - startAngle
        let progressAngle = startAngle + arcAngle * clampedProgress
        
        return Circle()
            .fill(Color.white)
            .frame(width: computedLineWidth, height: computedLineWidth)
            .shadow(color: .black.opacity(0.4), radius: 2)
            .offset(y: -radius)
            .rotationEffect(indicatorRotation(for: progressAngle))
            .animation(.easeInOut(duration: 0.4), value: progress)
    }

    private func indicatorRotation(for gaugeAngle: Angle) -> Angle {
        gaugeAngle + .degrees(90)
    }
}

private extension Comparable {
    func clamp(to limits: ClosedRange<Self>) -> Self {
        return min(max(self, limits.lowerBound), limits.upperBound)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        StressGaugeView(progress: 0.85, lineWidth: 14, tickCount: 24)
            .frame(width: 160)
    }
}
