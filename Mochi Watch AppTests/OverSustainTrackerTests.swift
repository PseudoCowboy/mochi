import Foundation
import XCTest
@testable import Mochi_Watch_App

@MainActor
final class OverSustainTrackerTests: XCTestCase {
    private let sustainSeconds: TimeInterval = 120

    func test_entersOver_thenLeavesBefore120s_doesNotFire() async {
        let clock = ManualClock()
        let scheduler = ManualScheduler()
        let viewModel = PetViewModel()
        viewModel.state = .calm

        var fireCount = 0
        let tracker = makeTracker(
            viewModel: viewModel,
            clock: clock,
            scheduler: scheduler,
            isEnabled: { true },
            onFire: { fireCount += 1 }
        )
        tracker.start()
        defer { tracker.stop() }
        await drain()

        viewModel.state = .over
        await drain()
        XCTAssertEqual(scheduler.scheduledDelays, [sustainSeconds])

        clock.advance(by: sustainSeconds / 2)
        viewModel.state = .calm
        await drain()

        clock.advance(by: sustainSeconds / 2)
        scheduler.fireAll()
        await drain()

        XCTAssertEqual(fireCount, 0)
    }

    func test_entersOver_andRemainsFor120s_fires() async {
        let clock = ManualClock()
        let scheduler = ManualScheduler()
        let viewModel = PetViewModel()
        viewModel.state = .calm

        var fireCount = 0
        let tracker = makeTracker(
            viewModel: viewModel,
            clock: clock,
            scheduler: scheduler,
            isEnabled: { true },
            onFire: { fireCount += 1 }
        )
        tracker.start()
        defer { tracker.stop() }
        await drain()

        viewModel.state = .over
        await drain()
        XCTAssertEqual(scheduler.scheduledDelays, [sustainSeconds])

        clock.advance(by: sustainSeconds)
        scheduler.fireAll()
        await drain()

        XCTAssertEqual(fireCount, 1)
    }

    func test_fires_onlyOncePerEpisode_evenIfStateRepeatsOver() async {
        let clock = ManualClock()
        let scheduler = ManualScheduler()
        let viewModel = PetViewModel()
        viewModel.state = .calm

        var fireCount = 0
        let tracker = makeTracker(
            viewModel: viewModel,
            clock: clock,
            scheduler: scheduler,
            isEnabled: { true },
            onFire: { fireCount += 1 }
        )
        tracker.start()
        defer { tracker.stop() }
        await drain()

        viewModel.state = .over
        await drain()
        clock.advance(by: sustainSeconds)
        scheduler.fireAll()
        await drain()

        XCTAssertEqual(fireCount, 1)

        viewModel.state = .over
        await drain()
        viewModel.state = .over
        await drain()

        XCTAssertEqual(scheduler.scheduledDelays, [sustainSeconds])

        clock.advance(by: sustainSeconds)
        scheduler.fireAll()
        await drain()

        XCTAssertEqual(fireCount, 1)
    }

    func test_reEntryToOver_afterLeaving_reArmsAndFiresAgain() async {
        let clock = ManualClock()
        let scheduler = ManualScheduler()
        let viewModel = PetViewModel()
        viewModel.state = .calm

        var fireCount = 0
        let tracker = makeTracker(
            viewModel: viewModel,
            clock: clock,
            scheduler: scheduler,
            isEnabled: { true },
            onFire: { fireCount += 1 }
        )
        tracker.start()
        defer { tracker.stop() }
        await drain()

        viewModel.state = .over
        await drain()
        clock.advance(by: sustainSeconds)
        scheduler.fireAll()
        await drain()

        viewModel.state = .okay
        await drain()

        viewModel.state = .over
        await drain()
        clock.advance(by: sustainSeconds)
        scheduler.fireAll()
        await drain()

        XCTAssertEqual(fireCount, 2)
    }

    func test_disabledByToggle_doesNotFire_butReArmingStillTracks() async {
        let clock = ManualClock()
        let scheduler = ManualScheduler()
        let toggle = ManualToggle(isEnabled: false)
        let viewModel = PetViewModel()
        viewModel.state = .calm

        var fireCount = 0
        let tracker = makeTracker(
            viewModel: viewModel,
            clock: clock,
            scheduler: scheduler,
            isEnabled: { toggle.isEnabled },
            onFire: { fireCount += 1 }
        )
        tracker.start()
        defer { tracker.stop() }
        await drain()

        viewModel.state = .over
        await drain()
        clock.advance(by: sustainSeconds)
        scheduler.fireAll()
        await drain()

        XCTAssertEqual(fireCount, 0)

        viewModel.state = .stressed
        await drain()
        toggle.isEnabled = true

        viewModel.state = .over
        await drain()
        clock.advance(by: sustainSeconds)
        scheduler.fireAll()
        await drain()

        XCTAssertEqual(fireCount, 1)
    }

    private func makeTracker(
        viewModel: PetViewModel,
        clock: ManualClock,
        scheduler: ManualScheduler,
        isEnabled: @escaping () -> Bool,
        onFire: @escaping @MainActor () -> Void
    ) -> OverSustainTracker {
        OverSustainTracker(
            viewModel: viewModel,
            sustainSeconds: sustainSeconds,
            isEnabled: isEnabled,
            now: clock.now,
            schedule: { delay, action in
                scheduler.schedule(after: delay, action: action)
            },
            onSustainedOver: onFire
        )
    }

    private func drain(_ iterations: Int = 8) async {
        for _ in 0..<iterations {
            await Task.yield()
        }
    }
}

private final class ManualClock {
    private(set) var currentDate: Date

    init(start: Date = Date(timeIntervalSince1970: 0)) {
        currentDate = start
    }

    func now() -> Date {
        currentDate
    }

    func advance(by seconds: TimeInterval) {
        currentDate = currentDate.addingTimeInterval(seconds)
    }
}

private final class ManualToggle {
    var isEnabled: Bool

    init(isEnabled: Bool) {
        self.isEnabled = isEnabled
    }
}

private final class ManualScheduler {
    private(set) var timers: [ManualTimer] = []

    var scheduledDelays: [TimeInterval] {
        timers.map(\.delay)
    }

    func schedule(after delay: TimeInterval, action: @escaping @MainActor () -> Void) -> any OverSustainCancellable {
        let timer = ManualTimer(delay: delay, action: action)
        timers.append(timer)
        return timer
    }

    @MainActor
    func fireAll() {
        timers.forEach { $0.fire() }
    }
}

private final class ManualTimer: OverSustainCancellable {
    let delay: TimeInterval

    private var action: (@MainActor () -> Void)?
    private var isCancelled = false

    init(delay: TimeInterval, action: @escaping @MainActor () -> Void) {
        self.delay = delay
        self.action = action
    }

    func cancel() {
        isCancelled = true
    }

    @MainActor
    func fire() {
        guard !isCancelled, let action else { return }
        self.action = nil
        action()
    }
}
