import Foundation

struct SummarySnapshot: Codable, Equatable {
    let calmMinutes: Int
    let overMinutes: Int
    let streak: Int
    let asOf: Date
}
