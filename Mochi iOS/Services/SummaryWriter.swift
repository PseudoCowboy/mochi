import Foundation
import BackgroundTasks
import HealthKit
import SwiftData

enum SummaryWriter {
    static let bgTaskIdentifier = "com.pseudocowboy.mochi.summary.refresh"
    static let defaultsKey = "summaryBackgroundEnabled"
    static let appGroupID = "group.com.pseudocowboy.mochi"
    static let summaryFileName = "summary.json"

    private static let refreshInterval: TimeInterval = 15 * 60

    private static let healthStore = HKHealthStore()
    private static var observerQuery: HKObserverQuery?

    static func register(_ scheduler: BGTaskScheduler) {
        scheduler.register(forTaskWithIdentifier: bgTaskIdentifier, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            handle(task: refreshTask)
        }
    }

    private static func handle(task: BGAppRefreshTask) {
        let work = Task { @MainActor in
            let ok = await writeSnapshot()
            scheduleNext()
            task.setTaskCompleted(success: ok)
        }
        task.expirationHandler = {
            work.cancel()
            task.setTaskCompleted(success: false)
        }
    }

    static func scheduleNext() {
        let enabled = (UserDefaults.standard.object(forKey: defaultsKey) as? Bool) ?? true
        guard enabled else { return }

        let request = BGAppRefreshTaskRequest(identifier: bgTaskIdentifier)
        request.earliestBeginDate = Date().addingTimeInterval(refreshInterval)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("[SummaryWriter] scheduleNext submit failed: \(error)")
        }
    }

    static func cancelScheduled() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: bgTaskIdentifier)
    }

    static func startObservingHeartRate() {
        guard HKHealthStore.isHealthDataAvailable(),
              let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            print("[SummaryWriter] HealthKit unavailable; skipping observer")
            return
        }
        guard healthStore.authorizationStatus(for: hrType) == .sharingAuthorized else {
            print("[SummaryWriter] heartRate not authorized on iOS; observer no-op")
            return
        }
        guard observerQuery == nil else { return }

        let query = HKObserverQuery(sampleType: hrType, predicate: nil) { _, completionHandler, error in
            if let error = error {
                print("[SummaryWriter] observer error: \(error)")
                completionHandler()
                return
            }
            Task { @MainActor in
                _ = await writeSnapshot()
                completionHandler()
            }
        }
        observerQuery = query
        healthStore.execute(query)
        healthStore.enableBackgroundDelivery(for: hrType, frequency: .immediate) { success, error in
            if let error = error {
                print("[SummaryWriter] enableBackgroundDelivery failed: \(error)")
            } else if !success {
                print("[SummaryWriter] enableBackgroundDelivery returned false")
            }
        }
    }

    static func stopObservingHeartRate() {
        if let query = observerQuery {
            healthStore.stop(query)
            observerQuery = nil
        }
        if let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            healthStore.disableBackgroundDelivery(for: hrType) { _, _ in }
        }
    }

    @MainActor
    @discardableResult
    static func writeSnapshot() async -> Bool {
        let now = Date()

        let calm: Int
        let over: Int
        do {
            let container = try StressHistoryReader.makeSharedContainer()
            let context = ModelContext(container)
            let reader = StressHistoryReader(context: context)
            let samples = try reader.last24Hours(now: now)
            let (c, o) = computeTodayMinutes(from: samples, now: now)
            calm = c
            over = o
        } catch {
            print("[SummaryWriter] failed to read SwiftData: \(error)")
            return false
        }

        let priorStreak = readExistingStreak()
        let snapshot = SummarySnapshot(
            calmMinutes: calm,
            overMinutes: over,
            streak: priorStreak,
            asOf: now
        )

        return writeSnapshot(snapshot)
    }

    @discardableResult
    static func writeSnapshot(_ snapshot: SummarySnapshot) -> Bool {
        guard let url = summaryFileURL() else {
            print("[SummaryWriter] missing App Group container")
            return false
        }
        return writeSnapshot(snapshot, to: url, write: { data, target in
            try data.write(to: target, options: .atomic)
        })
    }

    @discardableResult
    static func writeSnapshot(
        _ snapshot: SummarySnapshot,
        to url: URL,
        write: (Data, URL) throws -> Void = { data, target in
            try data.write(to: target, options: .atomic)
        }
    ) -> Bool {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        do {
            let data = try encoder.encode(snapshot)
            try write(data, url)
            return true
        } catch {
            print("[SummaryWriter] write failed: \(error)")
            return false
        }
    }

    private static func readExistingStreak() -> Int {
        guard let url = summaryFileURL(),
              let data = try? Data(contentsOf: url) else {
            return 0
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(SummarySnapshot.self, from: data).streak) ?? 0
    }

    private static func summaryFileURL() -> URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent(summaryFileName)
    }

    private static let gapCapSeconds: TimeInterval = 300

    private static func computeTodayMinutes(from samples: [StressSample], now: Date) -> (calm: Int, over: Int) {
        let startOfDay = Calendar.current.startOfDay(for: now)
        let today = samples
            .filter { $0.date >= startOfDay && $0.date <= now }
            .sorted { $0.date < $1.date }
        guard !today.isEmpty else { return (0, 0) }

        var calmSeconds: TimeInterval = 0
        var overSeconds: TimeInterval = 0

        if today.count >= 2 {
            for index in 0..<(today.count - 1) {
                let prev = today[index]
                let gap = today[index + 1].date.timeIntervalSince(prev.date)
                guard gap > 0 else { continue }
                let bucket = min(gap, gapCapSeconds)
                switch prev.state {
                case .calm: calmSeconds += bucket
                case .over: overSeconds += bucket
                default: break
                }
            }
        }

        if let last = today.last {
            let trailing = now.timeIntervalSince(last.date)
            if trailing > 0 {
                let bucket = min(trailing, gapCapSeconds)
                switch last.state {
                case .calm: calmSeconds += bucket
                case .over: overSeconds += bucket
                default: break
                }
            }
        }

        return (Int(calmSeconds / 60), Int(overSeconds / 60))
    }
}
