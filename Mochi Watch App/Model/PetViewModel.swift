import SwiftUI
import Combine
import Observation

@Observable
final class PetViewModel {
    var state: StressState = .calm
    var bpm: Int = 0
    var hrvMs: Int = 0
    
    private var heartRate: HeartRateService?
    
    init(heartRate: HeartRateService? = nil) {
        self.heartRate = heartRate
        if heartRate != nil {
            Task { @MainActor in
                startObserving()
            }
        }
    }
    
    @MainActor
    func refreshFromService() {
        guard let hr = heartRate, let v = hr.currentBPM else { return }
        bpm = v
        state = StressState.from(bpm: v)
    }
    
    @MainActor
    private func startObserving() {
        func observe() {
            withObservationTracking {
                _ = heartRate?.currentBPM
            } onChange: {
                Task { @MainActor [weak self] in
                    self?.refreshFromService()
                    self?.startObserving()
                }
            }
        }
        observe()
    }
    
#if targetEnvironment(simulator)
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
#endif
}