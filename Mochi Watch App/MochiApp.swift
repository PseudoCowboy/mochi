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
    @State private var onboarding = OnboardingState()
    @State private var breathPresenter = BreathPresenter()
    private let modelContainer: ModelContainer

    init() {
        let hr = HeartRateService()
        _heartRateService = State(wrappedValue: hr)
        let vm = PetViewModel(heartRate: hr)
        _viewModel = State(wrappedValue: vm)
        let presenter = BreathPresenter()
        _breathPresenter = State(wrappedValue: presenter)
        _stressNotifier = State(wrappedValue: StressNotifier(viewModel: vm, onOver: { [presenter] in
            presenter.trigger()
        }))

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
                    BreathView(viewState: BreathSessionViewState())
                        .environment(breathPresenter)
                }
                .task {
                    viewModel.attach(context: modelContainer.mainContext)
                    heartRateService.start()
                    await stressNotifier.requestAuthorization()
                    stressNotifier.start()
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
