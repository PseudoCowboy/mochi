import Foundation
import HealthKit
import XCTest
@testable import Mochi_Watch_App

final class OnboardingStateTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUpWithError() throws {
        try super.setUpWithError()
        suiteName = "com.skywalker.Mochi.OnboardingStateTests.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        try super.tearDownWithError()
    }

    func testDefaultValueIsFalseWhenKeyIsAbsent() {
        let state = OnboardingState(defaults: defaults)

        XCTAssertFalse(state.didCompleteOnboarding)
    }

    func testSetterWritesThroughToInjectedDefaultsSuite() {
        let state = OnboardingState(defaults: defaults)

        state.didCompleteOnboarding = true

        XCTAssertTrue(defaults.bool(forKey: "didCompleteOnboarding"))
    }

    func testReReadingAfterSetReturnsPersistedValue() {
        let state = OnboardingState(defaults: defaults)
        state.didCompleteOnboarding = true

        let reloadedState = OnboardingState(defaults: defaults)

        XCTAssertTrue(reloadedState.didCompleteOnboarding)
    }
}

final class OnboardingGateTests: XCTestCase {
    func testShouldShowOnboardingTruthTable() {
        let cases: [(didCompleteOnboarding: Bool, status: HKAuthorizationStatus, expected: Bool, label: String)] = [
            (false, .notDetermined, true, "first launch before HealthKit prompt"),
            (false, .sharingAuthorized, false, "first launch with HealthKit already authorized"),
            (false, .sharingDenied, false, "first launch with HealthKit denied"),
            (true, .notDetermined, false, "returning user before HealthKit prompt"),
            (true, .sharingAuthorized, false, "returning user with HealthKit authorized"),
            (true, .sharingDenied, false, "returning user with HealthKit denied")
        ]

        for testCase in cases {
            XCTAssertEqual(
                shouldShowOnboarding(
                    didCompleteOnboarding: testCase.didCompleteOnboarding,
                    authorizationStatus: testCase.status
                ),
                testCase.expected,
                testCase.label
            )
        }
    }

    func testFirstLaunchSmokeStateShowsOnboardingWhenHealthAuthorizationIsNotDetermined() throws {
        let defaults = try makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName(defaults)) }
        let state = OnboardingState(defaults: defaults)

        XCTAssertTrue(
            shouldShowOnboarding(
                didCompleteOnboarding: state.didCompleteOnboarding,
                authorizationStatus: .notDetermined
            )
        )
    }

    func testReturningUserSmokeStateSkipsOnboardingEvenWhenHealthAuthorizationIsNotDetermined() throws {
        let defaults = try makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName(defaults)) }
        let state = OnboardingState(defaults: defaults)
        state.didCompleteOnboarding = true

        XCTAssertFalse(
            shouldShowOnboarding(
                didCompleteOnboarding: state.didCompleteOnboarding,
                authorizationStatus: .notDetermined
            )
        )
    }

    private func shouldShowOnboarding(
        didCompleteOnboarding: Bool,
        authorizationStatus: HKAuthorizationStatus
    ) -> Bool {
        !didCompleteOnboarding && authorizationStatus == .notDetermined
    }

    private func makeIsolatedDefaults() throws -> UserDefaults {
        let suiteName = "com.skywalker.Mochi.OnboardingGateTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.set(suiteName, forKey: "__testSuiteName")
        defaults.removeObject(forKey: "didCompleteOnboarding")
        return defaults
    }

    private func defaultsSuiteName(_ defaults: UserDefaults) -> String {
        defaults.string(forKey: "__testSuiteName") ?? ""
    }
}
