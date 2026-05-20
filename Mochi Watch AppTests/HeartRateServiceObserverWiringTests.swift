import Foundation
import HealthKit
import XCTest
@testable import Mochi_Watch_App

@MainActor
final class HeartRateServiceObserverWiringTests: XCTestCase {
    private func makeStarter() -> (
        starter: HKObserverQueryStarter,
        handles: () -> [FakeObserverQueryHandle]
    ) {
        var handles: [FakeObserverQueryHandle] = []
        let starter: HKObserverQueryStarter = { type, onFire in
            let handle = FakeObserverQueryHandle(type: type, onFire: onFire)
            handles.append(handle)
            return handle
        }
        return (starter, { handles })
    }

    func testStartsObserverWhenAuthorized() throws {
        guard let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            throw XCTSkip("HealthKit did not vend the heart-rate quantity type in this runtime")
        }

        let store = FakeHealthStore()
        store.stubbedAuthorizationStatus = .sharingAuthorized
        let (starter, handles) = makeStarter()
        let service = HeartRateService(store: store, observerStarter: starter)

        service.start()

        let started = handles()
        XCTAssertEqual(started.count, 1, "exactly one observer should be started when authorized")
        XCTAssertEqual(started.first?.type, hrType)
    }

    func testDoesNotStartObserverWhenDenied() {
        let store = FakeHealthStore()
        store.stubbedAuthorizationStatus = .sharingDenied
        let (starter, handles) = makeStarter()
        let service = HeartRateService(store: store, observerStarter: starter)

        service.start()

        XCTAssertTrue(handles().isEmpty, "denied authorization must not start an observer")
    }

    func testDoesNotStartObserverWhenNotDetermined() {
        let store = FakeHealthStore()
        store.stubbedAuthorizationStatus = .notDetermined
        let (starter, handles) = makeStarter()
        let service = HeartRateService(store: store, observerStarter: starter)

        service.start()

        XCTAssertTrue(handles().isEmpty, "notDetermined authorization must not start an observer")
    }

    func testStartIsIdempotent() {
        let store = FakeHealthStore()
        store.stubbedAuthorizationStatus = .sharingAuthorized
        let (starter, handles) = makeStarter()
        let service = HeartRateService(store: store, observerStarter: starter)

        service.start()
        service.start()
        service.start()

        XCTAssertEqual(handles().count, 1, "repeated start() calls must not stack observers")
    }

    func testObserverFireFlowsBackIntoService() throws {
        guard HKQuantityType.quantityType(forIdentifier: .heartRate) != nil else {
            throw XCTSkip("HealthKit did not vend the heart-rate quantity type in this runtime")
        }

        let store = FakeHealthStore()
        store.stubbedAuthorizationStatus = .sharingAuthorized
        let (starter, handles) = makeStarter()
        let service = HeartRateService(store: store, observerStarter: starter)
        service.start()

        let initial = service.observerFireCount
        handles().first?.fire()
        handles().first?.fire()

        XCTAssertEqual(service.observerFireCount, initial + 2, "fires must be observable by the service")
    }
}
