import Foundation
import SwiftData

enum ComplicationDataProvider {
    static let appGroupID = "group.com.pseudocowboy.mochi"

    static func latest() -> StressPetEntry {
        let fallback = StressPetEntry(date: .now, state: .calm, bpm: 0)
        do {
            let configuration = ModelConfiguration(groupContainer: .identifier(appGroupID))
            let container = try ModelContainer(for: StressSample.self, configurations: configuration)
            let context = ModelContext(container)
            var descriptor = FetchDescriptor<StressSample>(
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            descriptor.fetchLimit = 1
            let samples = try context.fetch(descriptor)
            guard let sample = samples.first else { return fallback }
            return StressPetEntry(date: sample.date, state: sample.state, bpm: sample.bpm)
        } catch {
            return fallback
        }
    }
}
