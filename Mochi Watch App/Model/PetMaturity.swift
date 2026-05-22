import Foundation

enum PetMaturity {
    enum Level: Int, Comparable {
        case l0 = 0
        case l1 = 1
        case l2 = 2
        case l3 = 3

        static func < (a: Level, b: Level) -> Bool { a.rawValue < b.rawValue }
    }

    static func level(totalCount: Int, restingRatioLast7Days: Double) -> Level {
        if totalCount >= 300 && restingRatioLast7Days >= 0.7 { return .l3 }
        if totalCount >= 100 && restingRatioLast7Days >= 0.5 { return .l2 }
        if totalCount >= 20 { return .l1 }
        return .l0
    }

    static func compute(samples: [StressSample], now: Date = .now) -> Level {
        let total = samples.count
        let weekAgo = now.addingTimeInterval(-7 * 24 * 60 * 60)
        let recent = samples.filter { $0.date >= weekAgo && $0.date <= now }
        let ratio: Double
        if recent.isEmpty {
            ratio = 0
        } else {
            let resting = recent.reduce(into: 0) { acc, s in
                if s.state == .calm || s.state == .okay { acc += 1 }
            }
            ratio = Double(resting) / Double(recent.count)
        }
        return level(totalCount: total, restingRatioLast7Days: ratio)
    }
}

extension PetMaturity.Level {
    var evolutionStage: EvolutionStage {
        switch self {
        case .l0: return .egg
        case .l1: return .baby
        case .l2: return .teen
        case .l3: return .adult
        }
    }
}
