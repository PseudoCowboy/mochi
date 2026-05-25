import XCTest
@testable import Mochi_Watch_App

final class BreathSessionTests: XCTestCase {

    func testInitDefaultsPreserveProductionFourSevenEightPattern() {
        let state = BreathSessionViewState()
        let session = BreathSession(
            totalCycles: state.totalCycles,
            inhaleSeconds: state.inhaleSeconds,
            holdSeconds: state.holdSeconds,
            exhaleSeconds: state.exhaleSeconds,
            state: state
        )

        XCTAssertEqual(session.inhaleSeconds, 4)
        XCTAssertEqual(session.holdSeconds, 7)
        XCTAssertEqual(session.exhaleSeconds, 8)
    }

    func testStartDrivesPhasesThroughCycleAndEndsInDone() async {
        let state = BreathSessionViewState()
        let session = BreathSession(
            totalCycles: 1,
            inhaleSeconds: 1,
            holdSeconds: 1,
            exhaleSeconds: 1,
            tickDuration: .milliseconds(5),
            state: state
        )

        await session.start()

        XCTAssertEqual(state.phase, .done)
        XCTAssertEqual(state.remainingSeconds, 0)
        XCTAssertEqual(state.totalCycles, 1)
    }

    func testStartIteratesEachConfiguredCycleIndex() async {
        let state = BreathSessionViewState()
        let session = BreathSession(
            totalCycles: 3,
            inhaleSeconds: 1,
            holdSeconds: 1,
            exhaleSeconds: 1,
            tickDuration: .milliseconds(2),
            state: state
        )

        await session.start()

        XCTAssertEqual(state.phase, .done)
        XCTAssertEqual(state.cycleIndex, 2)
    }

    func testEndStopsSessionEarlyAndStillFinalizesToDone() async {
        let state = BreathSessionViewState()
        let session = BreathSession(
            totalCycles: 5,
            inhaleSeconds: 10,
            holdSeconds: 10,
            exhaleSeconds: 10,
            tickDuration: .milliseconds(5),
            state: state
        )

        let runner = Task { await session.start() }

        try? await Task.sleep(for: .milliseconds(20))
        await session.end()
        await runner.value

        XCTAssertEqual(state.phase, .done)
    }
}
