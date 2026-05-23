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
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Hero gauge with center avatar
                ZStack {
                    StressGaugeView(progress: viewModel.state.gaugeProgress, lineWidth: 14, tickCount: 24)
                        .frame(width: 174, height: 174)
                    CurvedGaugeCaption(text: hrvCaption)
                    Text(viewModel.state.stateEmoji)
                        .font(.largeTitle)
                        .dynamicTypeSize(.small ... .accessibility2)
                        .offset(y: 10)
                }
                .padding(.top, 22)
                .padding(.horizontal, 6)

                // Big numeric value
                Text("\(max(viewModel.hrvMs, viewModel.bpm))")
                    .font(.largeTitle.weight(.bold))
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
                        .font(.headline.weight(.bold))
                        .foregroundStyle(viewModel.state.headlineColor)
                    Text("✨")
                        .font(.caption2)
                }
                .padding(.top, 2)
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

    private let radius: CGFloat = 54
    private let arcDegrees: Double = 112

    var body: some View {
        let characters = Array(text)

        ZStack {
            ForEach(characters.indices, id: \.self) { index in
                let angle = angle(for: index, count: characters.count)

                Text(String(characters[index]))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.95))
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
