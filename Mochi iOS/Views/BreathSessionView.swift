import SwiftUI

/// iOS guided-breathing sheet driven by `BreathTimer`. Mirrors the watch's
/// Breath flow with an animated orb, phase text, and auto-dismiss on completion.
struct BreathSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var timer = BreathTimer()
    @State private var didStart = false
    @State private var dismissTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            RadialGradient(
                colors: [Color.calm.opacity(0.35), Color(white: 0.06)],
                center: .center,
                startRadius: 20,
                endRadius: 420
            )
            .ignoresSafeArea()

            VStack(spacing: 36) {
                Spacer()

                Text(timer.phase.label)
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
                    .contentTransition(.opacity)

                orb

                if timer.phase != .done && timer.phase != .idle {
                    Text("\(timer.remainingSeconds)")
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                        .contentTransition(.numericText())
                } else if timer.phase == .done {
                    Text("Nicely done. 🌿")
                        .font(.system(.title3, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                }

                Spacer()

                Button {
                    dismissTask?.cancel()
                    timer.stop()
                    dismiss()
                } label: {
                    Text(timer.phase == .done ? "Done" : "End")
                        .font(.system(.headline, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.calm.opacity(0.85), in: Capsule())
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 24)
            }
        }
        .onAppear {
            guard !didStart else { return }
            didStart = true
            timer.start()
        }
        .onChange(of: timer.phase) { _, newValue in
            if newValue == .done {
                dismissTask?.cancel()
                dismissTask = Task { @MainActor in
                    try? await Task.sleep(for: .seconds(2.5))
                    if !Task.isCancelled { dismiss() }
                }
            }
        }
        .onDisappear {
            dismissTask?.cancel()
            timer.stop()
        }
    }

    private var orb: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(red: 0.6, green: 0.85, blue: 1.0), Color.calm],
                        center: .topLeading,
                        startRadius: 4,
                        endRadius: 160
                    )
                )
                .overlay(
                    Circle().stroke(.white.opacity(0.4), lineWidth: 2)
                )
                .shadow(color: Color.calm.opacity(0.6), radius: 30)
        }
        .frame(width: 180, height: 180)
        .scaleEffect(timer.phase.orbScale)
        .animation(
            .easeInOut(duration: animationDuration),
            value: timer.phase
        )
    }

    private var animationDuration: Double {
        switch timer.phase {
        case .inhale: return Double(timer.inhaleSeconds)
        case .exhale: return Double(timer.exhaleSeconds)
        default: return 0.8
        }
    }
}
