import SwiftUI
import Combine

/// Main stress glance view. Single hero gauge with center avatar,
/// large numeric value below, and the rating label at the bottom.
/// The pet/maturity affordances live elsewhere (Summary, Pet evolution).
struct PetGlanceView: View {
    @Environment(PetViewModel.self) var viewModel

    // For manual rotation in simulator
    @State private var crownValue: Double = 0.0

    private var hrvCaption: String {
        "Last HRV · \(viewModel.hrvMs)ms · 15m ago"
    }

    var body: some View {
        ZStack {
            // Subtle state-tinted radial background for the "premium calm" feel
            RadialGradient(
                colors: [viewModel.state.growTint.opacity(0.28), .black],
                center: .center,
                startRadius: 8,
                endRadius: 180
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Hero gauge with Liquid Glass backplate + cloud mascot
                ZStack {
                    // Liquid Glass backplate disc behind the mascot
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 132, height: 132)
                        .overlay(
                            Circle()
                                .stroke(viewModel.state.growTint.opacity(0.55), lineWidth: 1)
                        )
                        .shadow(color: viewModel.state.growTint.opacity(0.55), radius: 10)
                        .shadow(color: .black.opacity(0.35), radius: 4, x: 0, y: 2)

                    StressGaugeView(progress: viewModel.state.gaugeProgress, lineWidth: 14, tickCount: 24)
                        .frame(width: 174, height: 174)

                    // Curved Liquid Glass caption capsule
                    CurvedGaugeCaption(text: hrvCaption, tint: viewModel.state.growTint)

                    // Cloud mascot (replaces static emoji, breathes subtly)
                    CloudMascotView(state: viewModel.state, fallbackEmoji: viewModel.state.stateEmoji)
                        .offset(y: 6)
                }
                .padding(.top, 22)
                .padding(.horizontal, 6)

                // Big numeric value
                Text("\(max(viewModel.hrvMs, viewModel.bpm))")
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.top, -12)
                    .dynamicTypeSize(.small ... .accessibility2)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Current Reading")
                    .accessibilityValue("\(max(viewModel.hrvMs, viewModel.bpm))")

                // Rating
                HStack(spacing: 4) {
                    Text("✨")
                        .font(.caption2)
                    Text(viewModel.state.label)
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(viewModel.state.growTint)
                    Text("✨")
                        .font(.caption2)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(
                    Capsule().fill(.ultraThinMaterial)
                )
                .overlay(
                    Capsule().stroke(viewModel.state.growTint.opacity(0.5), lineWidth: 0.8)
                )
                .padding(.top, 4)
                .dynamicTypeSize(.small ... .accessibility2)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Stress State")
                .accessibilityValue(viewModel.state.label)

                Spacer(minLength: 0)
            }
            .padding(.bottom, 4)
        }
        .focusable()
        .digitalCrownRotation($crownValue, from: 0, through: 100, by: 10,
                              sensitivity: .low, isContinuous: true,
                              isHapticFeedbackEnabled: true)
        .onChange(of: crownValue) { old, new in
#if targetEnvironment(simulator)
            if abs(new - old) >= 10 {
                withAnimation { viewModel.cycle() }
                crownValue = new > old ? 0 : 100
            }
#endif
        }
        .onTapGesture {
#if targetEnvironment(simulator)
            withAnimation { viewModel.cycle() }
#endif
        }
    }
}

#Preview {
    PetGlanceView()
        .environment(PetViewModel())
}

private struct CurvedGaugeCaption: View {
    let text: String
    var tint: Color = .white

    private let radius: CGFloat = 64
    private let arcDegrees: Double = 150

    var body: some View {
        let characters = Array(text)

        ZStack {
            // Glass arc backdrop
            Circle()
                .trim(from: 0.18, to: 0.32)
                .stroke(.ultraThinMaterial, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                .frame(width: 124, height: 124)
                .rotationEffect(.degrees(-90))
                .opacity(0.85)

            ForEach(characters.indices, id: \.self) { index in
                let angle = angle(for: index, count: characters.count)

                Text(String(characters[index]))
                    .font(.system(.caption2, design: .rounded).weight(.bold))
                    .foregroundStyle(tint.opacity(0.95))
                    .offset(y: -radius)
                    .rotationEffect(.degrees(angle))
                    .dynamicTypeSize(.small ... .accessibility2)
            }
        }
        .frame(width: 142, height: 142)
        .allowsHitTesting(false)
        .accessibilityLabel(Text(text))
    }

    private func angle(for index: Int, count: Int) -> Double {
        guard count > 1 else { return 0 }
        return (-arcDegrees / 2) + (arcDegrees * Double(index) / Double(count - 1))
    }
}
