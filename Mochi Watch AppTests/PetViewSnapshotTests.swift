import XCTest
import SnapshotTesting
import SwiftUI
@testable import Mochi_Watch_App

final class PetViewSnapshotTests: XCTestCase {
    private let isRecording = false

    func testPetView_Stages() {
        let stages: [EvolutionStage] = [.egg, .baby, .teen, .adult]
        for stage in stages {
            let view = PetView(stage: stage, mouth: .smile, blink: false)
            assertSnapshot(
                of: view,
                as: .image(layout: .fixed(width: 176, height: 215)),
                named: "stage_\(stage)",
                record: isRecording
            )
        }
    }
}
