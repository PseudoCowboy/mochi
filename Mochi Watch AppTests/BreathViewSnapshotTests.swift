import XCTest
import SnapshotTesting
import SwiftUI
@testable import Mochi_Watch_App

final class BreathViewSnapshotTests: XCTestCase {
    private let isRecording = false

    func testBreathPhases_41mm() {
        let phases: [BreathPhase] = [.inhale, .hold, .exhale, .done]
        for phase in phases {
            var state = BreathSessionViewState()
            state.phase = phase
            if phase == .inhale { state.remainingSeconds = 4 }
            if phase == .hold { state.remainingSeconds = 7 }
            if phase == .exhale { state.remainingSeconds = 8 }
            
            let view = BreathView(viewState: state, autoStart: false)
            assertSnapshot(
                of: view,
                as: .image(layout: .fixed(width: 176, height: 215)),
                named: "41mm_\(phase)",
                record: isRecording
            )
        }
    }

    func testBreathPhases_45mm() {
        let phases: [BreathPhase] = [.inhale, .hold, .exhale, .done]
        for phase in phases {
            var state = BreathSessionViewState()
            state.phase = phase
            if phase == .inhale { state.remainingSeconds = 4 }
            if phase == .hold { state.remainingSeconds = 7 }
            if phase == .exhale { state.remainingSeconds = 8 }
            
            let view = BreathView(viewState: state, autoStart: false)
            assertSnapshot(
                of: view,
                as: .image(layout: .fixed(width: 198, height: 242)),
                named: "45mm_\(phase)",
                record: isRecording
            )
        }
    }
}
