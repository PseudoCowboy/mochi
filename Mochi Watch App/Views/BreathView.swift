import SwiftUI
import Observation

struct BreathView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var viewState: BreathSessionViewState
    @State private var session: BreathSession?
    @State private var circleScale: CGFloat = 0.6
    
    private let autoStart: Bool

    init(viewState: BreathSessionViewState, autoStart: Bool = true) {
        self._viewState = State(initialValue: viewState)
        self.autoStart = autoStart
    }
    
    var body: some View {
        ZStack {
            RadialGradient(colors: [Color.growCalmBlue.opacity(0.35), .black],
                           center: .center, startRadius: 8, endRadius: 220)
                .ignoresSafeArea()

            VStack {
                Spacer()

                ZStack {
                    // Outer glow
                    Circle()
                        .fill(Color.growCalmBlue.opacity(0.45))
                        .blur(radius: 22)
                        .scaleEffect(circleScale * 1.05)
                        .frame(width: 140, height: 140)

                    // Liquid Glass orb
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Circle().fill(
                                RadialGradient(
                                    colors: [Color.growSkyBlue.opacity(0.65),
                                             Color.growCalmBlue.opacity(0.15)],
                                    center: UnitPoint(x: 0.35, y: 0.3),
                                    startRadius: 2,
                                    endRadius: 90
                                )
                            )
                        )
                        .overlay(
                            Circle().stroke(Color.white.opacity(0.35), lineWidth: 0.8)
                        )
                        .overlay(
                            // Specular highlight
                            Ellipse()
                                .fill(Color.white.opacity(0.35))
                                .frame(width: 38, height: 14)
                                .offset(x: -18, y: -32)
                                .blur(radius: 4)
                        )
                        .shadow(color: Color.growCalmBlue.opacity(0.6), radius: 14)
                        .scaleEffect(circleScale)
                        .frame(width: 140, height: 140)

                    VStack(spacing: 4) {
                        Text(phaseText)
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)

                        if viewState.remainingSeconds > 0 {
                            Text("\(viewState.remainingSeconds)")
                                .font(.system(.headline, design: .rounded).weight(.semibold))
                                .foregroundColor(.white.opacity(0.85))
                        }
                    }
                    .dynamicTypeSize(.small ... .accessibility2)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Breathing guide")
                .accessibilityValue("\(phaseText), \(viewState.remainingSeconds) seconds remaining")
                .accessibilityAddTraits(.updatesFrequently)

                Spacer()

                Button("Done") {
                    Task {
                        await session?.end()
                        dismiss()
                    }
                }
                .font(.system(.footnote, design: .rounded).weight(.semibold))
                .dynamicTypeSize(.small ... .accessibility2)
                .buttonStyle(.bordered)
                .tint(Color.growCalmBlue)
                .padding(.bottom, 8)
            }
        }
        .task {
            let newSession = BreathSession(
                totalCycles: viewState.totalCycles,
                inhaleSeconds: viewState.inhaleSeconds,
                holdSeconds: viewState.holdSeconds,
                exhaleSeconds: viewState.exhaleSeconds,
                state: viewState
            )
            session = newSession
            await newSession.start()
        }
        .onChange(of: viewState.phase) { _, newPhase in
            updateAnimation(for: newPhase)
            if newPhase == .done {
                dismiss()
            }
        }
    }
    
    private var phaseText: String {
        switch viewState.phase {
        case .inhale: return "Breathe in"
        case .hold: return "Hold"
        case .exhale: return "Breathe out"
        case .idle: return "Ready"
        case .done: return "Done"
        }
    }
    
    private func updateAnimation(for phase: BreathPhase) {
        switch phase {
        case .inhale:
            withAnimation(.easeInOut(duration: Double(viewState.inhaleSeconds))) {
                circleScale = 1.0
            }
        case .hold:
            withAnimation(.linear(duration: 0.1)) {
                circleScale = 1.0
            }
        case .exhale:
            withAnimation(.easeInOut(duration: Double(viewState.exhaleSeconds))) {
                circleScale = 0.6
            }
        case .idle, .done:
            withAnimation(.linear(duration: 0.2)) {
                circleScale = 0.6
            }
        }
    }
}
