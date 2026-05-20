import Foundation
import HealthKit

#if canImport(Mochi_Watch_App)
@testable import Mochi_Watch_App
#endif

final class FakeHealthStore: HKHealthStoreProtocol {
    var stubbedAuthorizationStatus: HKAuthorizationStatus = .notDetermined
    private(set) var authorizationLookups: [HKObjectType] = []
    private(set) var executedQueries: [HKQuery] = []
    private(set) var stoppedQueries: [HKQuery] = []

    func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus {
        authorizationLookups.append(type)
        return stubbedAuthorizationStatus
    }

    func execute(_ query: HKQuery) {
        executedQueries.append(query)
    }

    func stop(_ query: HKQuery) {
        stoppedQueries.append(query)
    }
}

/// Records that an observer was started for a given quantity type and lets the
/// test invoke the registered callback to simulate HealthKit delivering a new
/// sample notification.
final class FakeObserverQueryHandle {
    let type: HKQuantityType
    private let onFire: @MainActor () -> Void
    private(set) var fireCount: Int = 0

    init(type: HKQuantityType, onFire: @escaping @MainActor () -> Void) {
        self.type = type
        self.onFire = onFire
    }

    @MainActor
    func fire() {
        fireCount += 1
        onFire()
    }
}
