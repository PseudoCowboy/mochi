import SwiftUI
import HealthKit

struct OnboardingView: View {
    @Environment(HeartRateService.self) private var heartRate
    @Environment(OnboardingState.self) private var onboarding
    var onFinish: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Welcome to Mochi")
                    .font(.headline)
                
                Text("Mochi needs HealthKit access to read your heart rate and keep track of your stress levels.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                
                Button("Enable Health Access") {
                    Task {
                        _ = try? await heartRate.requestAuthorization()
                        onboarding.didCompleteOnboarding = true
                        onFinish()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .dynamicTypeSize(.small ... .accessibility3)
            .padding()
        }
    }
}
