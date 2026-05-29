import SwiftUI
import SwiftData

struct SummaryView: View {
    @Environment(\.modelContext) private var modelContext
    var now: Date

    @State private var calmMinutes: Int
    @State private var overMinutes: Int
    @State private var streak: Int

    @State private var selectedTab: Int = 0 // 0 for 24H, 1 for Week

    init(now: Date = .now, calmMinutes: Int = 0, overMinutes: Int = 0, streak: Int = 0) {
        self.now = now
        self._calmMinutes = State(initialValue: calmMinutes)
        self._overMinutes = State(initialValue: overMinutes)
        self._streak = State(initialValue: streak)
    }

    let hourlyData: [Double] = [
        0.1, 0.1, 0.1, 0.1, 0.1, 0.2,
        0.3, 0.5, 0.6, 0.7, 0.8, 0.7,
        0.6, 0.7, 0.8, 0.9, 0.8, 0.7,
        0.6, 0.5, 0.4, 0.3, 0.2, 0.1
    ]

    let dailyData: [Double] = [0.4, 0.5, 0.6, 0.5, 0.7, 0.3, 0.2]

    var body: some View {
        ZStack {
            RadialGradient(colors: [Color.growCalmBlue.opacity(0.18), .black],
                           center: .top, startRadius: 4, endRadius: 220)
                .ignoresSafeArea()

            VStack(spacing: 8) {
                // Liquid Glass segmented control
                HStack(spacing: 0) {
                    segmentButton("24H", index: 0)
                    segmentButton("Week", index: 1)
                }
                .padding(2)
                .background(
                    Capsule().fill(.ultraThinMaterial)
                )
                .overlay(
                    Capsule().stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                )
                .frame(height: 28)

                TabView(selection: $selectedTab) {
                    chartPage(title: "Stress · 24H",
                              data: hourlyData,
                              labels: ["0", "6", "12", "18"],
                              labelsEvenly: false,
                              caption: "Peak: 90 at 3pm")
                        .tag(0)
                        .accessibilityElement(children: .combine)

                    chartPage(title: "Stress · Week",
                              data: dailyData,
                              labels: ["M", "T", "W", "T", "F", "S", "S"],
                              labelsEvenly: true,
                              caption: "Peak: 70 on Friday")
                        .tag(1)
                        .accessibilityElement(children: .combine)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .padding(.horizontal, 4)
        }
        .task {
            let reader = StressHistoryReader(context: modelContext)
            let calm = (try? reader.calmMinutesToday(now: now)) ?? 0
            let over = (try? reader.overMinutesToday(now: now)) ?? 0

            calmMinutes = calm
            overMinutes = over

            DailySummaryStore.save(DailySummary(calm: calm, over: over), on: now)
            streak = DailySummaryStore.currentStreak(asOf: now, todayCalm: calm, todayOver: over)
        }
    }

    @ViewBuilder
    private func segmentButton(_ title: String, index: Int) -> some View {
        let selected = selectedTab == index
        Text(title)
            .font(.system(.caption2, design: .rounded).weight(selected ? .bold : .regular))
            .foregroundStyle(selected ? .white : Color.white.opacity(0.7))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(selected ? AnyShapeStyle(Color.growCalmBlue.opacity(0.55)) : AnyShapeStyle(Color.clear))
            )
            .overlay(
                Capsule().stroke(selected ? Color.white.opacity(0.25) : .clear, lineWidth: 0.5)
            )
            .contentShape(Rectangle())
            .onTapGesture { selectedTab = index }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(title) tab")
            .accessibilityValue(selected ? "Selected" : "Not Selected")
            .accessibilityHint("Double-tap to view \(title) data")
    }

    @ViewBuilder
    private func chartPage(title: String, data: [Double], labels: [String],
                           labelsEvenly: Bool, caption: String) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(.caption2, design: .rounded).weight(.bold))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            GeometryReader { geo in
                HStack(alignment: .bottom, spacing: data.count > 12 ? 2 : 6) {
                    ForEach(data.indices, id: \.self) { index in
                        JarBar(value: data[index], height: geo.size.height)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("Bar \(index + 1)")
                            .accessibilityValue("\(Int(data[index] * 100)) percent")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .bottom)
            }
            .frame(height: 58)

            if labelsEvenly {
                HStack {
                    ForEach(labels.indices, id: \.self) { i in
                        Text(labels[i]).frame(maxWidth: .infinity)
                    }
                }
                .font(.system(.caption2, design: .rounded))
                .foregroundColor(.secondary)
            } else {
                HStack {
                    Text(labels[0]).frame(maxWidth: .infinity, alignment: .leading)
                    Text(labels[1]).frame(maxWidth: .infinity, alignment: .center)
                    Text(labels[2]).frame(maxWidth: .infinity, alignment: .center)
                    Text(labels[3]).frame(maxWidth: .infinity, alignment: .trailing)
                }
                .font(.system(.caption2, design: .rounded))
                .foregroundColor(.secondary)
            }

            Text(caption)
                .font(.system(.caption2, design: .rounded))
                .foregroundColor(.secondary)
        }
    }
}

/// Liquid Glass jar bar that fills bottom-up with a calm-blue → amber gradient
/// based on its value.
private struct JarBar: View {
    let value: Double
    let height: CGFloat

    private var fillColors: [Color] {
        // calm-blue at low values, amber/ember at high values
        if value < 0.33 { return [.growSkyBlue, .growCalmBlue] }
        else if value < 0.66 { return [.growSun, .growSkyBlue] }
        else if value < 0.85 { return [.growAmber, .growSun] }
        else { return [.growEmber, .growAmber] }
    }

    var body: some View {
        let fillH = max(height * CGFloat(value), 6)
        ZStack(alignment: .bottom) {
            // Jar outline (full height) with Liquid Glass material
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 0.6)
                )

            // Amber/blue gradient liquid fill
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(
                    LinearGradient(colors: fillColors,
                                   startPoint: .top, endPoint: .bottom)
                )
                .frame(height: fillH)
                .overlay(
                    // Highlight at the top of the liquid (meniscus glow)
                    Capsule()
                        .fill(Color.white.opacity(0.35))
                        .frame(height: 1.2)
                        .padding(.horizontal, 2)
                        .offset(y: -fillH + 2),
                    alignment: .bottom
                )
                .padding(1.5)
        }
        .frame(height: height)
    }
}
