import XCTest
@testable import Mochi_Watch_App

final class BreathSessionTests: XCTestCase {

    func testInitDefaultsPreserveProductionFourSevenEightPattern() {
        let state = BreathSessionViewState()
        let cfg = BreathConfig(
            inhaleSeconds: state.inhaleSeconds,
            holdSeconds: state.holdSeconds,
            exhaleSeconds: state.exhaleSeconds,
            totalCycles: state.totalCycles
        )
        let session = BreathSession(config: cfg, state: state)

        XCTAssertEqual(session.inhaleSeconds, 4)
        XCTAssertEqual(session.holdSeconds, 7)
        XCTAssertEqual(session.exhaleSeconds, 8)
    }

    func testStartDrivesPhasesThroughCycleAndEndsInDone() async {
        let state = BreathSessionViewState()
        let cfg = BreathConfig(inhaleSeconds: 1, holdSeconds: 1, exhaleSeconds: 1, totalCycles: 1)
        let session = BreathSession(
            tickDuration: .milliseconds(5),
            config: cfg,
            state: state
        )

        await session.start()

        XCTAssertEqual(state.phase, .done)
        XCTAssertEqual(state.remainingSeconds, 0)
        XCTAssertEqual(state.totalCycles, 1)
    }

    func testStartIteratesEachConfiguredCycleIndex() async {
        let state = BreathSessionViewState()
        let cfg = BreathConfig(inhaleSeconds: 1, holdSeconds: 1, exhaleSeconds: 1, totalCycles: 3)
        let session = BreathSession(
            tickDuration: .milliseconds(2),
            config: cfg,
            state: state
        )

        await session.start()

        XCTAssertEqual(state.phase, .done)
        XCTAssertEqual(state.cycleIndex, 2)
    }

    func testEndStopsSessionEarlyAndStillFinalizesToDone() async {
        let state = BreathSessionViewState()
        let cfg = BreathConfig(inhaleSeconds: 10, holdSeconds: 10, exhaleSeconds: 10, totalCycles: 5)
        let session = BreathSession(
            tickDuration: .milliseconds(5),
            config: cfg,
            state: state
        )

        let runner = Task { await session.start() }

        try? await Task.sleep(for: .milliseconds(20))
        await session.end()
        await runner.value

        XCTAssertEqual(state.phase, .done)
    }
}
