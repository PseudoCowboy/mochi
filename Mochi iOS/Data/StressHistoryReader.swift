import Foundation
import SwiftData

@MainActor
struct StressHistoryReader {
    static let appGroupID = "group.com.pseudocowboy.mochi"

    let context: ModelContext

    func recentSamples(since: Date) throws -> [StressSample] {
        var descriptor = FetchDescriptor<StressSample>(
            predicate: #Predicate { $0.date >= since },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.includePendingChanges = true
        return try context.fetch(descriptor)
    }

    func last24Hours(now: Date = .now) throws -> [StressSample] {
        try recentSamples(since: now.addingTimeInterval(-24 * 60 * 60))
    }

    static func makeSharedContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(groupContainer: .identifier(appGroupID))
        return try ModelContainer(
            for: Schema([StressSample.self]),
            configurations: configuration
        )
    }
}
