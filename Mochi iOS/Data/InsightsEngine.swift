import Foundation

/// One day's worth of calm/over minutes, used to draw the weekly trend.
struct DayInsight: Identifiable, Equatable {
    let date: Date
    let calmMinutes: Int
    let overMinutes: Int
    var id: Date { date }
}

/// Everything the iOS "Today" dashboard needs, derived from real `StressSample`s.
struct Insights: Equatable {
    var todayCalmMinutes: Int
    var todayOverMinutes: Int
    var goalMinutes: Int
    var streak: Int
    var weeklyTrend: [DayInsight]     // oldest → newest, 7 entries
    var stage: EvolutionStage
    var nextStage: EvolutionStage?
    var stageProgress: Double         // 0...1 toward next stage
    var totalSamples: Int
    var latestState: StressState?

    var goalMet: Bool { DailyGoal.isMet(calmMinutes: todayCalmMinutes, goal: goalMinutes) }

    var goalProgress: Double {
        guard goalMinutes > 0 else { return 0 }
        return min(1, Double(todayCalmMinutes) / Double(goalMinutes))
    }

    static let empty = Insights(
        todayCalmMinutes: 0,
        todayOverMinutes: 0,
        goalMinutes: DailyGoal.defaultMinutes,
        streak: 0,
        weeklyTrend: [],
        stage: .egg,
        nextStage: .baby,
        stageProgress: 0,
        totalSamples: 0,
        latestState: nil
    )
}

/// Derives `Insights` from samples. Pure/static so it is trivially testable and
/// mirrors `SummaryWriter`'s gap-bucket minute attribution.
enum InsightsEngine {
    private static let gapCapSeconds: TimeInterval = 300

    static func compute(
        from samples: [StressSample],
        now: Date = .now,
        calendar: Calendar = .current,
        goalMinutes: Int = DailyGoal.minutes
    ) -> Insights {
        let sorted = samples.sorted { $0.date < $1.date }
        let startOfToday = calendar.startOfDay(for: now)

        let (todayCalm, todayOver) = minutes(
            from: sorted,
            dayStart: startOfToday,
            dayEnd: now,
            terminal: now
        )

        // Persist today's tally so streak survives across launches.
        DailyMinutesStore.save(calm: todayCalm, over: todayOver, on: startOfToday, calendar: calendar)

        // Weekly trend: 7 days oldest → newest (today last).
        var trend: [DayInsight] = []
        for offset in stride(from: 6, through: 0, by: -1) {
            guard let dayStart = calendar.date(byAdding: .day, value: -offset, to: startOfToday) else { continue }
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
            let terminal = min(now, dayEnd)
            let (c, o): (Int, Int)
            if offset == 0 {
                (c, o) = (todayCalm, todayOver)
            } else {
                (c, o) = minutes(from: sorted, dayStart: dayStart, dayEnd: dayEnd, terminal: terminal)
            }
            trend.append(DayInsight(date: dayStart, calmMinutes: c, overMinutes: o))
        }

        let streak = DailyMinutesStore.currentStreak(asOf: now, calendar: calendar)

        // Evolution stage + progress toward the next stage.
        let level = PetMaturity.compute(samples: samples, now: now)
        let stage = level.evolutionStage
        let (next, progress) = stageProgress(level: level, totalSamples: samples.count, samples: samples, now: now)

        return Insights(
            todayCalmMinutes: todayCalm,
            todayOverMinutes: todayOver,
            goalMinutes: goalMinutes,
            streak: streak,
            weeklyTrend: trend,
            stage: stage,
            nextStage: next,
            stageProgress: progress,
            totalSamples: samples.count,
            latestState: sorted.last?.state
        )
    }

    /// Calm/over minutes within [dayStart, dayEnd], attributing each sample's
    /// state to the interval until the next sample (capped at `gapCapSeconds`).
    static func minutes(
        from sortedSamples: [StressSample],
        dayStart: Date,
        dayEnd: Date,
        terminal: Date
    ) -> (calm: Int, over: Int) {
        let day = sortedSamples.filter { $0.date >= dayStart && $0.date < dayEnd }
        guard !day.isEmpty else { return (0, 0) }

        var calmSeconds: TimeInterval = 0
        var overSeconds: TimeInterval = 0

        if day.count >= 2 {
            for index in 0..<(day.count - 1) {
                let prev = day[index]
                let gap = day[index + 1].date.timeIntervalSince(prev.date)
                guard gap > 0 else { continue }
                let bucket = min(gap, gapCapSeconds)
                accumulate(state: prev.state, seconds: bucket, calm: &calmSeconds, over: &overSeconds)
            }
        }

        if let last = day.last {
            let trailing = terminal.timeIntervalSince(last.date)
            if trailing > 0 {
                accumulate(state: last.state, seconds: min(trailing, gapCapSeconds), calm: &calmSeconds, over: &overSeconds)
            }
        }

        return (Int(calmSeconds / 60), Int(overSeconds / 60))
    }

    private static func accumulate(state: StressState, seconds: TimeInterval, calm: inout TimeInterval, over: inout TimeInterval) {
        switch state {
        case .calm: calm += seconds
        case .over: over += seconds
        default: break
        }
    }

    private static func stageProgress(
        level: PetMaturity.Level,
        totalSamples: Int,
        samples: [StressSample],
        now: Date
    ) -> (next: EvolutionStage?, progress: Double) {
        switch level {
        case .l0:
            return (.baby, min(1, Double(totalSamples) / 20.0))
        case .l1:
            return (.teen, min(1, Double(totalSamples) / 100.0))
        case .l2:
            return (.adult, min(1, Double(totalSamples) / 300.0))
        case .l3:
            return (nil, 1)
        }
    }
}
