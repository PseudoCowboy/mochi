import SwiftUI
import Combine

struct PetGlanceView: View {
    @Environment(PetViewModel.self) var viewModel
    @State private var blink: Bool = false
    @State private var pulsePhase: Bool = false
    
    // For manual rotation in simulator
    @State private var crownValue: Double = 0.0
    
    let timer = Timer.publish(every: 4.2, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 0) {
            // Status pill and Time row
            HStack {
                HStack(spacing: 4) {
                    Circle()
                        .fill(viewModel.state.headlineColor)
                        .frame(width: 6, height: 6)
                        .shadow(color: viewModel.state.headlineColor.opacity(0.8), radius: 3)
                    
                    Text(viewModel.state.label)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(viewModel.state.headlineColor)
                }
                Spacer()
                Text(Date(), format: .dateTime.hour().minute())
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(viewModel.state.headlineColor)
            }
            .padding(.horizontal, 8)
            .padding(.top, 4)
            
            // Pet Stage
            ZStack {
                // Glow
                Circle()
                    .fill(
                        RadialGradient(gradient: Gradient(colors: [viewModel.state.headlineColor, Color.clear]), center: .center, startRadius: 0, endRadius: 65)
                    )
                    .frame(width: 130, height: 130)
                    .opacity(viewModel.state == .over ? (pulsePhase ? 1.0 : 0.6) : 0.25)
                    .blur(radius: 6)
                    .animation(
                        viewModel.state == .over
                            ? .easeInOut(duration: 0.5).repeatForever(autoreverses: true)
                            : .default,
                        value: pulsePhase
                    )
                
                PetView(mouth: viewModel.state.mouthShape, blink: blink)
                    .frame(width: 90, height: 90)
                    .animation(.easeInOut(duration: 0.4), value: viewModel.state.mouthShape)
                
                // Speech bubble
                VStack {
                    HStack {
                        Spacer()
                        Text(viewModel.state.speech)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(Color(white: 0.15))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white)
                            .cornerRadius(10)
                            .shadow(color: Color.black.opacity(0.3), radius: 4, y: 2)
                            .overlay(
                                // speech bubble tail
                                Triangle()
                                    .fill(Color.white)
                                    .frame(width: 8, height: 6)
                                    .rotationEffect(.degrees(180))
                                    .offset(x: -12, y: 3),
                                alignment: .bottomTrailing
                            )
                    }
                    Spacer()
                }
                .padding(.trailing, 4)
                .padding(.top, -10)
            }
            .frame(height: 110)
            .onReceive(timer) { _ in
                blink = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    blink = false
                }
            }
            .onTapGesture {
#if targetEnvironment(simulator)
                withAnimation {
                    viewModel.cycle()
                }
#endif
            }
            
            // Message
            VStack(spacing: 2) {
                Text(viewModel.state.label.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.2)
                    .foregroundColor(viewModel.state.headlineColor)
                
                Text(viewModel.state.message)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(height: 28)
            }
            .padding(.horizontal, 4)
            
            Spacer(minLength: 4)
            
            // Metrics
            MetricRow(bpm: viewModel.bpm, hrv: viewModel.hrvMs)
                .padding(.bottom, 6)
            
            // Stress Ring
            StressRingView(segments: viewModel.state.ringSegments, activeColor: viewModel.state.headlineColor)
                .padding(.bottom, 4)
        }
        .focusable()
        .digitalCrownRotation($crownValue, from: 0, through: 100, by: 10, sensitivity: .low, isContinuous: true, isHapticFeedbackEnabled: true)
        .onChange(of: crownValue) { old, new in
#if targetEnvironment(simulator)
            if abs(new - old) >= 10 {
                withAnimation {
                    viewModel.cycle()
                }
                crownValue = new > old ? 0 : 100 // Reset to avoid hitting limits
            }
#endif
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

// Simple triangle shape for speech bubble tail
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

#Preview {
    PetGlanceView()
        .environment(PetViewModel())
}
