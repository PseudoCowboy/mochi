import Foundation
import XCTest
@testable import Mochi_Watch_App

@MainActor
final class StressNotifierObserverSmokeTests: XCTestCase {
    private let defaultsKey = "mochi.stressNotifier.lastOverAt"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: defaultsKey)
        super.tearDown()
    }

    /// Drains the MainActor cooperative queue so observation onChange handlers
    /// — which dispatch into `Task { @MainActor in ... }` — get a chance to run
    /// before the test inspects post-state.
    private func drain(_ iterations: Int = 8) async {
        for _ in 0..<iterations {
            await Task.yield()
        }
    }

    func testTransitionToOverInvokesOnOverExactlyOnce() async {
        let viewModel = PetViewModel()
        viewModel.state = .calm

        var onOverInvocations = 0
        let notifier = StressNotifier(viewModel: viewModel) {
            onOverInvocations += 1
        }
        notifier.start()
        await drain()

        viewModel.state = .over
        await drain()

        XCTAssertEqual(onOverInvocations, 1, "exactly one onOver call should fire on calm→over transition")
    }

    func testRepeatedOverWithinThrottleDoesNotInvokeOnOverAgain() async {
        let viewModel = PetViewModel()
        viewModel.state = .calm

        var onOverInvocations = 0
        let notifier = StressNotifier(viewModel: viewModel) {
            onOverInvocations += 1
        }
        notifier.start()
        await drain()

        viewModel.state = .over
        await drain()
        viewModel.state = .calm
        await drain()
        viewModel.state = .over
        await drain()

        XCTAssertEqual(onOverInvocations, 1, "subsequent over transitions within the 30-minute throttle must not refire")
    }

    func testNonOverTransitionsDoNotInvokeOnOver() async {
        let viewModel = PetViewModel()
        viewModel.state = .calm

        var onOverInvocations = 0
        let notifier = StressNotifier(viewModel: viewModel) {
            onOverInvocations += 1
        }
        notifier.start()
        await drain()

        viewModel.state = .okay
        await drain()
        viewModel.state = .stressed
        await drain()

        XCTAssertEqual(onOverInvocations, 0, "non-over transitions must never invoke onOver")
    }
}
