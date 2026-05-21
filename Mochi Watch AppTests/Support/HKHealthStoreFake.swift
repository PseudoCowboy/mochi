import Foundation
import HealthKit
@testable import Mochi_Watch_App

final class FakeHKHealthStore: HKHealthStoreProtocol {
    var stubbedAuthorizationStatus: HKAuthorizationStatus = .notDetermined
    private(set) var authorizationLookups: [HKObjectType] = []
    private(set) var executedQueries: [HKQuery] = []
    private(set) var stoppedQueries: [HKQuery] = []

    var status: HKAuthorizationStatus {
        get { stubbedAuthorizationStatus }
        set { stubbedAuthorizationStatus = newValue }
    }

    var executed: [HKQuery] { executedQueries }
    var stopped: [HKQuery] { stoppedQueries }

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

typealias FakeHealthStore = FakeHKHealthStore

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
