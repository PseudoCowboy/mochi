import Foundation
import HealthKit
import Observation

protocol HKHealthStoreProtocol: AnyObject {
    func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus
    func execute(_ query: HKQuery)
    func stop(_ query: HKQuery)
}

extension HKHealthStore: HKHealthStoreProtocol {}

/// Constructs an active observer-like handle for `type` and arranges for `onFire`
/// to be invoked each time a new sample is delivered. The returned value is the
/// handle the caller is expected to retain (and later stop). Default uses a real
/// `HKAnchoredObjectQuery` running against the underlying store.
typealias HKObserverQueryStarter = (HKQuantityType, @escaping @MainActor () -> Void) -> Any

@Observable
final class HeartRateService {
    enum AuthState {
        case notDetermined
        case denied
        case authorized
        case unavailable
    }

    enum AuthorizationError: Error {
        case healthDataUnavailable
        case missingHeartRateType
    }

    private(set) var currentBPM: Int?
    private(set) var lastSampleDate: Date?
    private(set) var authState: AuthState = .notDetermined
    private(set) var authorizationStatus: HKAuthorizationStatus = .notDetermined

    @ObservationIgnored private let store: HKHealthStoreProtocol
    @ObservationIgnored private let observerStarter: HKObserverQueryStarter?
    @ObservationIgnored private var anchor: HKQueryAnchor?
    @ObservationIgnored private var query: HKAnchoredObjectQuery?
    @ObservationIgnored private(set) var observerHandle: Any?

    private var heartRateType: HKQuantityType? {
        HKQuantityType.quantityType(forIdentifier: .heartRate)
    }

    private var bpmUnit: HKUnit {
        HKUnit.count().unitDivided(by: .minute())
    }

    init(
        store: HKHealthStoreProtocol = HKHealthStore(),
        observerStarter: HKObserverQueryStarter? = nil
    ) {
        self.store = store
        self.observerStarter = observerStarter
        guard HKHealthStore.isHealthDataAvailable(), let hrType = heartRateType else {
            authState = .unavailable
            return
        }
        let status = store.authorizationStatus(for: hrType)
        authorizationStatus = status
        authState = Self.mapAuthState(from: status)
    }

    @discardableResult
    func requestAuthorization() async throws -> HKAuthorizationStatus {
        guard HKHealthStore.isHealthDataAvailable() else {
            await MainActor.run { self.authState = .unavailable }
            throw AuthorizationError.healthDataUnavailable
        }
        guard let hrType = heartRateType else {
            await MainActor.run { self.authState = .unavailable }
            throw AuthorizationError.missingHeartRateType
        }

        let readTypes: Set<HKObjectType> = [hrType]
        let shareTypes: Set<HKSampleType> = []

        if let concreteStore = store as? HKHealthStore {
            try await concreteStore.requestAuthorization(toShare: shareTypes, read: readTypes)
        }
        let status = store.authorizationStatus(for: hrType)
        await MainActor.run {
            self.authorizationStatus = status
            self.authState = Self.mapAuthState(from: status)
        }
        return status
    }

    func start() {
        guard authState == .authorized, let hrType = heartRateType else {
            return
        }

        if let starter = observerStarter {
            guard observerHandle == nil else { return }
            observerHandle = starter(hrType) { [weak self] in
                self?.handleObserverFire()
            }
            return
        }

        guard query == nil else { return }

        let q = HKAnchoredObjectQuery(
            type: hrType,
            predicate: nil,
            anchor: anchor,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, newAnchor, _ in
            self?.handle(samples: samples, newAnchor: newAnchor)
        }

        q.updateHandler = { [weak self] _, samples, _, newAnchor, _ in
            self?.handle(samples: samples, newAnchor: newAnchor)
        }

        query = q
        store.execute(q)
    }

    func stop() {
        if let q = query {
            store.stop(q)
            query = nil
        }
        if let handle = observerHandle as? HKQuery {
            store.stop(handle)
        }
        observerHandle = nil
    }

    private static func mapAuthState(from status: HKAuthorizationStatus) -> AuthState {
        switch status {
        case .sharingAuthorized:
            return .authorized
        case .sharingDenied:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .notDetermined
        }
    }

    /// Test-visible counter incremented every time an injected observer fires.
    /// Production observers go through `handle(samples:newAnchor:)` directly.
    @ObservationIgnored private(set) var observerFireCount: Int = 0

    private func handleObserverFire() {
        observerFireCount &+= 1
    }

    private func handle(samples: [HKSample]?, newAnchor: HKQueryAnchor?) {
        if let newAnchor = newAnchor {
            anchor = newAnchor
        }

        guard let latest = samples?.compactMap({ $0 as? HKQuantitySample }).last else {
            return
        }

        let value = latest.quantity.doubleValue(for: bpmUnit)
        let bpm = Int(value.rounded())
        let endDate = latest.endDate

        Task { @MainActor in
            self.currentBPM = bpm
            self.lastSampleDate = endDate
        }
    }
}
