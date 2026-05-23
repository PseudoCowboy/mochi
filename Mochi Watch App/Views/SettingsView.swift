import SwiftUI
import HealthKit

struct SettingsView: View {
    @Environment(HeartRateService.self) private var heartRate
    @AppStorage(.breathAutoTriggerEnabledKey) private var autoTriggerEnabled = true
    
    var body: some View {
        List {
            Section("Coaching") {
                Toggle("Auto breath prompts", isOn: $autoTriggerEnabled)
                Text("Open a 60-second breath when you've been overwhelmed for a while.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Section("Permissions") {
                Button(action: {
                    Task {
                        _ = try? await heartRate.requestAuthorization()
                    }
                }) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Health Access")
                        Text(statusText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .dynamicTypeSize(.small ... .accessibility3)
                }
                
                if heartRate.authorizationStatus == .sharingDenied {
                    Text("Open the Health app on iPhone → Sharing → Mochi")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .dynamicTypeSize(.small ... .accessibility3)
                }
            }
        }
        .navigationTitle("Settings")
    }
    
    private var statusText: String {
        switch heartRate.authorizationStatus {
        case .notDetermined:
            return "Not Determined"
        case .sharingAuthorized:
            return "Sharing Authorized"
        case .sharingDenied:
            return "Sharing Denied"
        @unknown default:
            return "Unknown"
        }
    }
}
