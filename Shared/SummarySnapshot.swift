import Foundation

struct SummarySnapshot: Codable, Equatable {
    let calmMinutes: Int
    let overMinutes: Int
    let streak: Int
    let asOf: Date
    /// Daily calm-minutes goal ("Perfect Day"). Defaults to `DailyGoal.defaultMinutes`
    /// so snapshots written before this field existed still decode cleanly.
    let goalMinutes: Int

    init(
        calmMinutes: Int,
        overMinutes: Int,
        streak: Int,
        asOf: Date,
        goalMinutes: Int = 30
    ) {
        self.calmMinutes = calmMinutes
        self.overMinutes = overMinutes
        self.streak = streak
        self.asOf = asOf
        self.goalMinutes = goalMinutes
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        calmMinutes = try c.decode(Int.self, forKey: .calmMinutes)
        overMinutes = try c.decode(Int.self, forKey: .overMinutes)
        streak = try c.decode(Int.self, forKey: .streak)
        asOf = try c.decode(Date.self, forKey: .asOf)
        // Backward compatible: older summary.json has no goalMinutes.
        goalMinutes = try c.decodeIfPresent(Int.self, forKey: .goalMinutes) ?? 30
    }

    /// Whether today's calm minutes have reached the daily goal — a "Perfect Day".
    var goalMet: Bool { goalMinutes > 0 && calmMinutes >= goalMinutes }

    /// Progress toward the daily goal, clamped to 0...1.
    var goalProgress: Double {
        guard goalMinutes > 0 else { return 0 }
        return min(1, Double(calmMinutes) / Double(goalMinutes))
    }
}
