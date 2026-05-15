import Foundation
import HealthKit
import Observation

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

    @ObservationIgnored private let store = HKHealthStore()
    @ObservationIgnored private var anchor: HKQueryAnchor?
    @ObservationIgnored private var query: HKAnchoredObjectQuery?

    private var heartRateType: HKQuantityType? {
        HKQuantityType.quantityType(forIdentifier: .heartRate)
    }

    private var bpmUnit: HKUnit {
        HKUnit.count().unitDivided(by: .minute())
    }

    init() {
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

        try await store.requestAuthorization(toShare: shareTypes, read: readTypes)
        let status = store.authorizationStatus(for: hrType)
        await MainActor.run {
            self.authorizationStatus = status
            self.authState = Self.mapAuthState(from: status)
        }
        return status
    }

    func start() {
        guard authState == .authorized, query == nil, let hrType = heartRateType else {
            return
        }

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
