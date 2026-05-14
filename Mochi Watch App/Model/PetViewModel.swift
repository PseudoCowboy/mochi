import SwiftUI
import Combine
import Observation

@Observable
final class PetViewModel {
    var state: StressState = .calm
    var bpm: Int = 68
    var hrvMs: Int = 62
    
    func cycle() {
        let all = StressState.allCases
        let currentIndex = all.firstIndex(of: state) ?? 0
        let nextIndex = (currentIndex + 1) % all.count
        state = all[nextIndex]
        
        switch state {
        case .calm:
            bpm = 68
            hrvMs = 62
        case .okay:
            bpm = 78
            hrvMs = 48
        case .stressed:
            bpm = 96
            hrvMs = 32
        case .over:
            bpm = 112
            hrvMs = 22
        }
    }
}
