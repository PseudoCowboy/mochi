import Foundation
import WatchConnectivity

/// Watch side of the watch → phone bridge.
///
/// Activates a `WCSession` and pushes real watch-measured data to the iPhone:
///   * new `StressSample`s via `transferUserInfo` (queued, guaranteed background
///     delivery — nothing is lost while the phone is unreachable), and
///   * the latest summary snapshot via `updateApplicationContext`
///     (last-write-wins "current state").
///
/// App Groups do not cross the watch/phone boundary, so this is the only path by
/// which the iOS app, widget, App Intents and streak ever see the real data.
final class WatchSyncSender: NSObject {
    static let shared = WatchSyncSender()

    private let session: WCSession?

    private override init() {
        session = WCSession.isSupported() ? .default : nil
        super.init()
    }

    /// Call once at launch. Safe to call repeatedly.
    func activate() {
        guard let session else { return }
        session.delegate = self
        if session.activationState != .activated {
            session.activate()
        }
    }

    /// Queue one or more freshly recorded samples for guaranteed background
    /// delivery. Each sample carries a stable `syncID` so the phone can dedup.
    func send(samples: [StressSample]) {
        guard let session, !samples.isEmpty else { return }
        let dtos: [[String: Any]] = samples.map { sample in
            StressSampleDTO(
                id: sample.syncID ?? UUID().uuidString,
                date: sample.date,
                bpm: sample.bpm,
                stateRaw: sample.stateRaw
            ).dictionary
        }
        let payload: [String: Any] = [
            WatchSyncKeys.payloadType: WatchSyncPayloadType.stressSamples,
            WatchSyncKeys.samples: dtos,
        ]
        // transferUserInfo queues to the OS and survives app suspension / an
        // unreachable counterpart, retrying until delivered.
        session.transferUserInfo(payload)
    }

    /// Push the latest "current state" summary. Overwrites any previously queued
    /// context (last-write-wins) which is exactly what a live dashboard wants.
    func send(summary: WatchSummaryDTO) {
        guard let session, session.activationState == .activated else { return }
        do {
            try session.updateApplicationContext(summary.applicationContext)
        } catch {
            // Non-fatal: the next summary update will overwrite the context.
            print("[WatchSyncSender] updateApplicationContext failed: \(error)")
        }
    }
}

extension WatchSyncSender: WCSessionDelegate {
    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let error {
            print("[WatchSyncSender] activation error: \(error)")
        }
    }
}
