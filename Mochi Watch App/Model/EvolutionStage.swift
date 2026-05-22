import Foundation

enum EvolutionStage: Int, CaseIterable, Sendable {
    case egg = 0
    case baby = 1
    case teen = 2
    case adult = 3

    var displayName: String {
        switch self {
        case .egg: return "Egg"
        case .baby: return "Baby"
        case .teen: return "Teen"
        case .adult: return "Adult"
        }
    }
}
