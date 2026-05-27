//
//  MochiApp.swift
//  Mochi Watch App
//
//  Created by 姜泽甲 on 2026/1/21.
//

import SwiftUI
import SwiftData
import HealthKit

@main
struct Mochi_Watch_AppApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var heartRateService: HeartRateService
    @State private var viewModel: PetViewModel
    @State private var stressNotifier: StressNotifier
    @State private var overSustainTracker: OverSustainTracker
    @State private var onboarding = OnboardingState()
    @State private var breathPresenter = BreathPresenter()
    @AppStorage(.breathAutoTriggerEnabledKey) private var autoTriggerEnabled = true
    private let modelContainer: ModelContainer

    init() {
        let hr = HeartRateService()
        _heartRateService = State(wrappedValue: hr)
        let vm = PetViewModel(heartRate: hr)
        _viewModel = State(wrappedValue: vm)
        let presenter = BreathPresenter()
        _breathPresenter = State(wrappedValue: presenter)
        _stressNotifier = State(wrappedValue: StressNotifier(viewModel: vm, onOver: { [presenter] in
            presenter.trigger(config: .manualDefault)
        }))
        let onboardingState = OnboardingState()
        _onboarding = State(wrappedValue: onboardingState)

        // We capture presenter by reference since it's a class
        let tracker = OverSustainTracker(
            viewModel: vm,
            isEnabled: { 
                let ud = UserDefaults.standard
                if ud.object(forKey: .breathAutoTriggerEnabledKey) == nil { return true }
                return ud.bool(forKey: .breathAutoTriggerEnabledKey)
            },
            onSustainedOver: { [presenter, onboardingState, hr] in
                let isOnboardingPresented = !onboardingState.didCompleteOnboarding && hr.authorizationStatus == .notDetermined
                guard !isOnboardingPresented else { return }
                guard !presenter.shouldPresentBreath else { return }
                presenter.trigger(config: .autoRecovery)
            }
        )
        _overSustainTracker = State(wrappedValue: tracker)

        let container: ModelContainer
        do {
            let configuration = ModelConfiguration(groupContainer: .identifier("group.com.pseudocowboy.mochi"))
            container = try ModelContainer(for: StressSample.self, configurations: configuration)
        } catch {
            fatalError("Failed to create ModelContainer for StressSample: \(error)")
        }
        self.modelContainer = container
    }

    private var isOnboardingPresented: Bool {
        !onboarding.didCompleteOnboarding && heartRateService.authorizationStatus == .notDetermined
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(viewModel)
                .environment(heartRateService)
                .environment(onboarding)
                .environment(breathPresenter)
                .modelContainer(modelContainer)
                .sheet(isPresented: Binding(
                    get: { !onboarding.didCompleteOnboarding && heartRateService.authorizationStatus == .notDetermined },
                    set: { _ in }
                )) {
                    OnboardingView {
                        onboarding.didCompleteOnboarding = true
                    }
                    .environment(heartRateService)
                    .environment(onboarding)
                }
                .sheet(isPresented: Binding(
                    get: { breathPresenter.shouldPresentBreath && !isOnboardingPresented },
                    set: { newValue in breathPresenter.shouldPresentBreath = newValue }
                )) {
                    BreathView(config: breathPresenter.pendingConfig,
                               viewState: BreathSessionViewState(config: breathPresenter.pendingConfig))
                        .environment(breathPresenter)
                }
                .task {
                    viewModel.attach(context: modelContainer.mainContext)
                    heartRateService.start()
                    await stressNotifier.requestAuthorization()
                    stressNotifier.start()
                    overSustainTracker.start()
                }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .background {
                heartRateService.stop()
            } else if newPhase == .active {
                heartRateService.start()
            }
        }
    }
}
