import SwiftUI
import Observation

struct BreathView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var viewState: BreathSessionViewState
    @State private var session: BreathSession?
    @State private var config: BreathConfig
    @State private var circleScale: CGFloat = 0.6

    private let autoStart: Bool

    init(config: BreathConfig, viewState: BreathSessionViewState, autoStart: Bool = true) {
        self._config = State(initialValue: config)
        self._viewState = State(initialValue: viewState)
        self.autoStart = autoStart
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack {
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(Color.calm)
                        .scaleEffect(circleScale)
                        .frame(width: 140, height: 140)
                    
                    VStack(spacing: 4) {
                        Text(phaseText)
                            .font(.title3.weight(.bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        
                        if viewState.remainingSeconds > 0 {
                            Text("\(viewState.remainingSeconds)")
                                .font(.headline.weight(.semibold))
                                .foregroundColor(.white.opacity(0.8))
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
                .font(.footnote.weight(.semibold))
                .dynamicTypeSize(.small ... .accessibility2)
                .buttonStyle(.bordered)
                .tint(Color.muted)
                .padding(.bottom, 8)
            }
        }
        .task {
            let newSession = BreathSession(config: config, state: viewState)
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
