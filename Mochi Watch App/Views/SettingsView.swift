import SwiftUI
import HealthKit

struct SettingsView: View {
    @Environment(HeartRateService.self) private var heartRate
    @AppStorage(.breathAutoTriggerEnabledKey) private var autoTriggerEnabled = true

    var body: some View {
        ZStack {
            RadialGradient(colors: [Color.growCalmBlue.opacity(0.18), .black],
                           center: .top, startRadius: 4, endRadius: 220)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    sectionHeader("Coaching")
                    GlassCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Toggle("Auto breath prompts", isOn: $autoTriggerEnabled)
                                .tint(Color.growCalmBlue)
                                .font(.system(.footnote, design: .rounded))
                            Text("Open a 60-second breath when you've been overwhelmed for a while.")
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }

                    sectionHeader("Permissions")
                    GlassCard {
                        Button(action: {
                            Task { _ = try? await heartRate.requestAuthorization() }
                        }) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Health Access")
                                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                                    .foregroundStyle(.white)
                                Text(statusText)
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .dynamicTypeSize(.small ... .accessibility3)
                        }
                        .buttonStyle(.plain)
                    }

                    if heartRate.authorizationStatus == .sharingDenied {
                        GlassCard {
                            Text("Open the Health app on iPhone → Sharing → Mochi")
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(.secondary)
                                .dynamicTypeSize(.small ... .accessibility3)
                        }
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 6)
            }
        }
        .navigationTitle("Settings")
    }

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(.caption2, design: .rounded).weight(.bold))
            .foregroundStyle(Color.growCalmBlue.opacity(0.9))
            .padding(.leading, 6)
            .padding(.top, 4)
    }

    private var statusText: String {
        switch heartRate.authorizationStatus {
        case .notDetermined: return "Not Determined"
        case .sharingAuthorized: return "Sharing Authorized"
        case .sharingDenied: return "Sharing Denied"
        @unknown default: return "Unknown"
        }
    }
}

/// Liquid Glass card container — `.regularMaterial` rounded rect with a soft
/// border and shadow.
private struct GlassCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.regularMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.15), lineWidth: 0.6)
            )
            .shadow(color: .black.opacity(0.35), radius: 4, x: 0, y: 2)
    }
}
