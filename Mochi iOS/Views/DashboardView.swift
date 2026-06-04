import SwiftUI
import SwiftData

/// mochi's richer iOS "Today" surface: Perfect Day goal ring, live state, calm/
/// over minutes, calm-day streak, weekly trend, and pet evolution progress —
/// all computed from real `StressSample`s.
struct DashboardView: View {
    var onBreathe: () -> Void
    var onCheckIn: () -> Void

    // Dashboard insights need more than the last 24h: the weekly trend spans 7
    // days and evolution maturity depends on the all-time sample count.
    @Query(sort: \StressSample.date, order: .reverse) private var samples: [StressSample]
    @State private var appState = MochiAppState.shared
    @State private var insights: Insights = .empty

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                goalCard
                actionsRow
                statsRow
                WeeklyTrendChart(trend: insights.weeklyTrend, goalMinutes: insights.goalMinutes)
                    .dashboardCard()
                evolutionCard
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(backgroundGradient.ignoresSafeArea())
        .navigationTitle("Today")
        .onAppear(perform: recompute)
        .onChange(of: samples.count) { _, _ in recompute() }
        .onChange(of: appState.refreshToken) { _, _ in recompute() }
    }

    private func recompute() {
        insights = InsightsEngine.compute(from: samples)
    }

    // MARK: Goal card

    private var goalCard: some View {
        VStack(spacing: 12) {
            GoalRingView(calmMinutes: insights.todayCalmMinutes, goalMinutes: insights.goalMinutes)
            if let state = insights.latestState {
                statePill(state)
            } else {
                Text("Wear your Apple Watch to start tracking.")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Color.muted)
            }
        }
        .frame(maxWidth: .infinity)
        .dashboardCard()
    }

    private func statePill(_ state: StressState) -> some View {
        Text(state.label)
            .font(.system(.subheadline, design: .rounded).weight(.semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
            .background(state.headlineColor.opacity(0.18), in: Capsule())
            .foregroundStyle(state.headlineColor)
    }

    // MARK: Actions

    private var actionsRow: some View {
        HStack(spacing: 12) {
            actionButton(title: "Breathe", systemImage: "wind", tint: .calm, action: onBreathe)
            actionButton(title: "Calm Check-In", systemImage: "leaf.fill", tint: .okay, action: onCheckIn)
        }
    }

    private func actionButton(title: String, systemImage: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.title3)
                Text(title)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .foregroundStyle(tint)
        }
        .buttonStyle(.plain)
    }

    // MARK: Stats

    private var statsRow: some View {
        HStack(spacing: 12) {
            statTile(value: "\(insights.todayCalmMinutes)", unit: "min", label: "Calm today", color: .calm)
            statTile(value: "\(insights.todayOverMinutes)", unit: "min", label: "Over today", color: .over)
            statTile(value: "\(insights.streak)", unit: "🔥", label: "Day streak", color: .stressed)
        }
    }

    private func statTile(value: String, unit: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundStyle(color)
                Text(unit)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(color.opacity(0.8))
            }
            Text(label)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(Color.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .dashboardCard()
    }

    // MARK: Evolution

    private var evolutionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Pet Evolution")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(Color.ink)
                Spacer()
                Text(insights.stage.displayName)
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(Color.calm)
            }

            if let next = insights.nextStage {
                ProgressView(value: insights.stageProgress)
                    .tint(Color.calm)
                Text("\(Int(insights.stageProgress * 100))% to \(next.displayName) · \(insights.totalSamples) readings")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Color.muted)
            } else {
                Text("Fully grown — your mochi is all grown up! 🎉")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Color.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dashboardCard()
    }

    private var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [Color.calm.opacity(0.10), Color(white: 0.97)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Card styling

private struct DashboardCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.surface)
                    .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
            )
    }
}

extension View {
    func dashboardCard() -> some View { modifier(DashboardCard()) }
}
