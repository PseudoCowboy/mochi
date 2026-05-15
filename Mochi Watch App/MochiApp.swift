//
//  MochiApp.swift
//  Mochi Watch App
//
//  Created by 姜泽甲 on 2026/1/21.
//

import SwiftUI
import SwiftData

@main
struct Mochi_Watch_AppApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var heartRateService: HeartRateService
    @State private var viewModel: PetViewModel
    @State private var stressNotifier: StressNotifier
    private let modelContainer: ModelContainer

    init() {
        let hr = HeartRateService()
        _heartRateService = State(wrappedValue: hr)
        let vm = PetViewModel(heartRate: hr)
        _viewModel = State(wrappedValue: vm)
        _stressNotifier = State(wrappedValue: StressNotifier(viewModel: vm))

        let container: ModelContainer
        do {
            let configuration = ModelConfiguration(groupContainer: .identifier("group.com.pseudocowboy.mochi"))
            container = try ModelContainer(for: StressSample.self, configurations: configuration)
        } catch {
            fatalError("Failed to create ModelContainer for StressSample: \(error)")
        }
        self.modelContainer = container
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(viewModel)
                .modelContainer(modelContainer)
                .task {
                    viewModel.attach(context: modelContainer.mainContext)
                    await heartRateService.requestAuthorization()
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
