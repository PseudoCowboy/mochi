import SwiftUI

/// Grow-style cloud mascot: a soft cloud silhouette with eyes that subtly
/// "breathes" (scale 1.0 → 1.04 over 4s, ease-in-out). Tint shifts blue↔amber
/// based on the supplied `StressState`. The original state emoji is shown as a
/// small overlay so the existing affordance remains as a fallback.
struct CloudMascotView: View {
    let state: StressState
    var fallbackEmoji: String? = nil

    @State private var breathe = false
    @State private var drift = false

    var body: some View {
        ZStack {
            // Soft outer glow that color-matches state and drifts subtly
            Circle()
                .fill(state.growTint.opacity(0.40))
                .blur(radius: 16)
                .scaleEffect(breathe ? 1.08 : 0.96)
                .offset(x: drift ? 3 : -3, y: drift ? -2 : 2)
                .animation(.easeInOut(duration: 6).repeatForever(autoreverses: true), value: drift)

            // Cloud body
            CloudShape()
                .fill(state.growGradient)
                .overlay(
                    CloudShape()
                        .stroke(Color.white.opacity(0.35), lineWidth: 0.8)
                )
                .shadow(color: state.growTint.opacity(0.5), radius: 6, x: 0, y: 0)

            // Eyes
            HStack(spacing: 14) {
                eye
                eye
            }
            .offset(y: -2)

            // Optional fallback emoji (small, low opacity) — keeps original
            // semantics but doesn't dominate the mascot
            if let emoji = fallbackEmoji {
                Text(emoji)
                    .font(.caption2)
                    .opacity(0.0) // hidden; kept for accessibility/fallback wiring
                    .accessibilityHidden(true)
            }
        }
        .frame(width: 92, height: 64)
        .scaleEffect(breathe ? 1.04 : 1.0)
        .animation(.easeInOut(duration: 4).repeatForever(autoreverses: true), value: breathe)
        .onAppear { breathe = true; drift = true }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Mochi mascot")
        .accessibilityValue(state.label)
    }

    private var eye: some View {
        Capsule()
            .fill(Color.white.opacity(0.95))
            .frame(width: 6, height: breathe ? 7 : 8)
            .overlay(
                Circle()
                    .fill(Color.black.opacity(0.85))
                    .frame(width: 3, height: 3)
            )
    }
}

/// Rounded cloud silhouette built from overlapping circles.
struct CloudShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        // base
        p.addRoundedRect(in: CGRect(x: 0, y: h * 0.55, width: w, height: h * 0.45),
                         cornerSize: CGSize(width: h * 0.25, height: h * 0.25))
        // bumps
        p.addEllipse(in: CGRect(x: w * 0.05, y: h * 0.30, width: w * 0.40, height: h * 0.55))
        p.addEllipse(in: CGRect(x: w * 0.28, y: h * 0.05, width: w * 0.45, height: h * 0.70))
        p.addEllipse(in: CGRect(x: w * 0.55, y: h * 0.25, width: w * 0.42, height: h * 0.60))
        return p
    }
}

#Preview {
    VStack(spacing: 16) {
        CloudMascotView(state: .calm)
        CloudMascotView(state: .okay)
        CloudMascotView(state: .stressed)
        CloudMascotView(state: .over)
    }
    .padding()
    .background(Color.black)
}
