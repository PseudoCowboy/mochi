import HealthKit
import XCTest
@testable import Mochi_Watch_App

final class HeartRateServiceAuthorizationTests: XCTestCase {
    func testRequestAuthorizationThrowsWhenHealthDataIsUnavailable() async throws {
        guard !HKHealthStore.isHealthDataAvailable() else {
            throw XCTSkip("HealthKit reports health data as available in this runtime; the unavailable branch cannot be forced without an injectable HKHealthStore, so simulator/device runs skip this negative path explicitly.")
        }

        let service = HeartRateService()

        do {
            _ = try await service.requestAuthorization()
            XCTFail("Expected requestAuthorization() to throw healthDataUnavailable")
        } catch let error as HeartRateService.AuthorizationError {
            guard case .healthDataUnavailable = error else {
                return XCTFail("Expected healthDataUnavailable, got \(error)")
            }
        } catch {
            XCTFail("Expected HeartRateService.AuthorizationError, got \(error)")
        }
    }

    func testRequestAuthorizationSuccessUpdatesReturnedStatusAndAuthStateMirror() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw XCTSkip("HealthKit is unavailable in this runtime; live authorization success requires a watchOS simulator or device with HealthKit available.")
        }

        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            throw XCTSkip("HealthKit did not vend the heart-rate quantity type in this runtime, so the live authorization path cannot be exercised.")
        }

        let initialStatus = HKHealthStore().authorizationStatus(for: heartRateType)
        guard initialStatus != .notDetermined else {
            throw XCTSkip("A clean simulator would display the system HealthKit prompt for .notDetermined; pre-grant or deny Health access, or inject a mock HKHealthStore, to exercise this live success-path assertion non-interactively.")
        }

        let service = HeartRateService()
        let returnedStatus = try await service.requestAuthorization()

        XCTAssertEqual(service.authorizationStatus, returnedStatus)
        assertAuthState(service.authState, mirrors: returnedStatus)
    }

    private func assertAuthState(
        _ authState: HeartRateService.AuthState,
        mirrors authorizationStatus: HKAuthorizationStatus,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        switch (authorizationStatus, authState) {
        case (.notDetermined, .notDetermined),
             (.sharingDenied, .denied),
             (.sharingAuthorized, .authorized):
            return
        default:
            XCTFail(
                "Expected authState to mirror authorizationStatus \(authorizationStatus), got \(authState)",
                file: file,
                line: line
            )
        }
    }
}
