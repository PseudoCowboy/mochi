import Foundation
import SwiftData
import WatchConnectivity
import WidgetKit

/// iPhone side of the watch → phone bridge.
///
/// Receives real watch-measured `StressSample`s (`transferUserInfo`) and the
/// latest summary snapshot (`updateApplicationContext`), persists them into the
/// **iPhone's** App-Group SwiftData store, and refreshes the shared `summary.json`
/// + widget timelines so `InsightsEngine`, the dashboard, App Intents and the
/// streak all reflect the watch's data — which App Groups alone never delivered.
final class PhoneSyncReceiver: NSObject {
    static let shared = PhoneSyncReceiver()

    private let session: WCSession?
    /// The app's shared SwiftData container (same App-Group store the UI reads).
    private var container: ModelContainer?

    private override init() {
        session = WCSession.isSupported() ? .default : nil
        super.init()
    }

    /// Call once at launch with the app's shared container.
    func activate(container: ModelContainer) {
        self.container = container
        guard let session else { return }
        session.delegate = self
        if session.activationState != .activated {
            session.activate()
        }
    }

    // MARK: - Apply incoming data

    private func applySamples(_ payload: [String: Any]) {
        guard let raw = payload[WatchSyncKeys.samples] as? [[String: Any]] else { return }
        let dtos = raw.compactMap(StressSampleDTO.init(dictionary:))
        guard !dtos.isEmpty else { return }

        Task { @MainActor in
            guard let container = self.container ?? (try? StressHistoryReader.makeSharedContainer()) else { return }
            let context = ModelContext(container)

            var inserted = 0
            for dto in dtos {
                let id = dto.id
                // Dedup by the stable sync id so retries never double-insert.
                var descriptor = FetchDescriptor<StressSample>(
                    predicate: #Predicate { $0.syncID == id }
                )
                descriptor.fetchLimit = 1
                let existing = (try? context.fetch(descriptor)) ?? []
                guard existing.isEmpty else { continue }

                let state = StressState(rawValue: dto.stateRaw) ?? .calm
                context.insert(StressSample(date: dto.date, bpm: dto.bpm, state: state, syncID: id))
                inserted += 1
            }

            guard inserted > 0 else { return }
            do {
                try context.save()
            } catch {
                // WCSession treats the payload as delivered once this delegate
                // returns and will not redeliver, so surface save failures loudly
                // rather than dropping watch samples silently.
                print("[PhoneSyncReceiver] failed to persist \(inserted) synced samples: \(error)")
                return
            }

            // Recompute minutes/streak/summary from the now-updated SwiftData so
            // the phone's single source of truth is the synced watch data.
            await SummaryWriter.writeSnapshot()
            WidgetCenter.shared.reloadAllTimelines()
            MochiAppState.shared.notifyDataChanged()
        }
    }

    private func applySummary(_ context: [String: Any]) {
        guard let dto = WatchSummaryDTO(applicationContext: context) else { return }
        Task { @MainActor in
            // Drop stale contexts: applicationContext can arrive out of order or
            // after a newer phone-computed summary (e.g. a local check-in), so
            // never regress a fresher snapshot.
            if let existing = SummaryStore.read(), existing.asOf > dto.asOf {
                return
            }
            // Last-write-wins "current state". Seed today's tally so the
            // sample-path recompute stays coherent, but trust the watch's own
            // streak — it is computed from the watch's full daily history, which
            // is the authoritative source on the phone (the iPhone's
            // DailyMinutesStore is only sparsely seeded).
            DailyMinutesStore.save(calm: dto.calmMinutes, over: dto.overMinutes, on: dto.asOf)
            let snapshot = SummarySnapshot(
                calmMinutes: dto.calmMinutes,
                overMinutes: dto.overMinutes,
                streak: dto.streak,
                asOf: dto.asOf,
                goalMinutes: DailyGoal.minutes
            )
            SummaryWriter.writeSnapshot(snapshot)
            WidgetCenter.shared.reloadAllTimelines()
            MochiAppState.shared.notifyDataChanged()
        }
    }
}

extension PhoneSyncReceiver: WCSessionDelegate {
    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let error {
            print("[PhoneSyncReceiver] activation error: \(error)")
        }
        // Drain any application context that arrived before activation completed.
        if !session.receivedApplicationContext.isEmpty {
            applySummary(session.receivedApplicationContext)
        }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard userInfo[WatchSyncKeys.payloadType] as? String == WatchSyncPayloadType.stressSamples else { return }
        applySamples(userInfo)
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        applySummary(applicationContext)
    }

    // iOS-only lifecycle: a session can be torn down when switching the paired
    // watch. Reactivate so delivery resumes against the new device.
    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
}
