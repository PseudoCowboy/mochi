import Foundation

#if canImport(Mochi_Watch_App)
@testable import Mochi_Watch_App

enum PetViewModelFixtures {
    /// One deterministic input bundle per `EvolutionStage`.
    struct PetViewInputs {
        let stage: EvolutionStage
        let mouth: PetView.Mouth
        let blink: Bool
    }

    static func inputs(for stage: EvolutionStage) -> PetViewInputs {
        switch stage {
        case .egg:
            return PetViewInputs(stage: .egg, mouth: .neutral, blink: false)
        case .baby:
            return PetViewInputs(stage: .baby, mouth: .smile, blink: false)
        case .teen:
            return PetViewInputs(stage: .teen, mouth: .neutral, blink: false)
        case .adult:
            return PetViewInputs(stage: .adult, mouth: .smile, blink: false)
        }
    }

    static let allStageInputs: [PetViewInputs] = EvolutionStage.allCases.map(inputs(for:))

    /// `PetViewModel` builder with deterministic stress/maturity inputs.
    /// `heartRate` is left nil so no observation tasks are kicked off.
    static func viewModel(
        stage: EvolutionStage,
        state: StressState = .calm,
        bpm: Int = 68,
        hrvMs: Int = 62
    ) -> PetViewModel {
        let vm = PetViewModel(heartRate: nil)
        vm.state = state
        vm.bpm = bpm
        vm.hrvMs = hrvMs
        vm.maturity = maturityLevel(for: stage)
        return vm
    }

    private static func maturityLevel(for stage: EvolutionStage) -> PetMaturity.Level {
        switch stage {
        case .egg: return .l0
        case .baby: return .l1
        case .teen: return .l2
        case .adult: return .l3
        }
    }
}
#endif
