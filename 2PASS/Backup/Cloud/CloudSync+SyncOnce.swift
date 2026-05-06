// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

extension CloudSync {

    /// Performs a single CloudKit sync pass, awaitable.
    ///
    /// Bridges `CloudSync`'s event-driven flow (`synchronize()` is fire-and-forget; result
    /// is delivered via the in-module `addFinishedSyncHandler` / `addStateChangedHandler`
    /// callback hooks on `CloudHandler`) into the imperative `BackupSynchronizing.performSync(...)`
    /// shape required by `BackupSyncSession`.
    ///
    /// **Coexistence with legacy callers.** Legacy paths (push handlers, app foregrounding,
    /// vault edits) call `synchronize(fromPush:)` directly without awaiting. They share the
    /// same instance and `SyncHandler.isSyncing` gate. If a legacy sync is in flight when
    /// `syncOnce` is called, the inner `synchronize()` becomes a no-op and the awaiter
    /// adopts the legacy sync's outcome through the same `finishedSync` handler. This is
    /// the documented behaviour — convergence picks up any divergence on the next pass.
    ///
    /// **State pre-check.** A state-change handler only catches transitions; if the current
    /// state is already terminal (`.disabled` or `.enabledNotAvailable`) when entering, no
    /// transition fires. The first thing this method does after registering its handlers is
    /// evaluate `currentState` and resume immediately if terminal.
    ///
    /// **Cancellation.** Cooperative — resumes the continuation with `.cancelled` if the
    /// task is cancelled. The underlying CloudKit operation continues in the background;
    /// CloudKit does not surface a cancellation primitive at this layer.
    public func syncOnce(overwritingVault: Bool) async throws(BackupSyncError) -> BackupSyncOutcome {
        do {
            return try await syncOncePass(overwritingVault: overwritingVault)
        } catch let err as BackupSyncError {
            throw err
        } catch {
            throw BackupSyncError.unexpected("CloudSync.syncOnce: \(error)")
        }
    }

    private func syncOncePass(overwritingVault: Bool) async throws -> BackupSyncOutcome {
        try Task.checkCancellation()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                Bridge.bridge(
                    cloudSync: self,
                    overwritingVault: overwritingVault,
                    continuation: continuation
                )
            }
        } onCancel: {
            // Best-effort: the underlying CloudKit op continues in the background. Our
            // continuation is resumed with .cancelled by the bridge if it was still pending.
        }
    }
}

// MARK: - Bridge

private final class Bridge: @unchecked Sendable {
    private let continuation: CheckedContinuation<BackupSyncOutcome, Error>
    private weak var cloudSync: CloudSync?
    private var finishedSyncToken: UUID?
    private var stateToken: UUID?
    private var resumed = false
    private let lock = NSLock()

    static func bridge(
        cloudSync: CloudSync,
        overwritingVault: Bool,
        continuation: CheckedContinuation<BackupSyncOutcome, Error>
    ) {
        let bridge = Bridge(cloudSync: cloudSync, continuation: continuation)
        bridge.start(overwritingVault: overwritingVault)
    }

    private init(cloudSync: CloudSync, continuation: CheckedContinuation<BackupSyncOutcome, Error>) {
        self.cloudSync = cloudSync
        self.continuation = continuation
    }

    private func start(overwritingVault: Bool) {
        guard let cloudSync else {
            resume(.failure(BackupSyncError.iCloudUnavailable))
            return
        }

        // Strong `self` is intentional. The `Bridge` instance is created locally in
        // `Bridge.bridge(...)` and has no other strong owner once that factory returns —
        // so a `[weak self]` capture would let `Bridge` deallocate before CloudKit's
        // async callback fires, leaving `self?.resume(...)` a no-op and the awaiting
        // `syncOnce` hanging forever (and the session's `.finished` event never broadcast,
        // surfacing as stuck "Syncing…" UI on every iCloud row). The closures stored on
        // `CloudHandler` keep `Bridge` alive exactly until `resume(...)` removes them via
        // the saved tokens — at which point ARC reclaims it normally. The reverse direction
        // is already weak (`private weak var cloudSync: CloudSync?`), so this does not form
        // a retain cycle through the engine.
        finishedSyncToken = cloudSync.addFinishedSyncHandler { applied in
            self.resume(.success(BackupSyncOutcome(appliedRemoteChanges: applied)))
        }

        stateToken = cloudSync.addStateChangedHandler { state in
            self.evaluateTerminalState(state)
        }

        // Pre-check: if already in a terminal state, resume now — the state-change handler
        // won't fire because the state isn't changing.
        evaluateTerminalState(cloudSync.currentState)
        if isResumed { return }

        if overwritingVault {
            // CloudKit's analogue to "ignore remote, push local": flag the merge handler so
            // a deviceID conflict resolves in favour of this device. Note this also flips
            // multi-device-sync to enabled — acceptable here because `overwritingVault` is
            // an explicit "take over" intent from the caller.
            cloudSync.setMultiDeviceSyncEnabled(true, takingOver: true)
        }

        cloudSync.synchronize(fromPush: false)
    }

    private func evaluateTerminalState(_ state: CloudCurrentState) {
        switch state {
        case .disabled:
            resume(.failure(BackupSyncError.iCloudUnavailable))
        case .enabledNotAvailable(let reason):
            resume(.failure(Self.mapNotAvailable(reason)))
        case .unknown, .enabled:
            // Intermediate; keep waiting.
            break
        }
    }

    private var isResumed: Bool {
        lock.lock()
        defer { lock.unlock() }
        return resumed
    }

    private func resume(_ result: Result<BackupSyncOutcome, Error>) {
        lock.lock()
        if resumed {
            lock.unlock()
            return
        }
        resumed = true
        let finishedSyncToken = self.finishedSyncToken
        let stateToken = self.stateToken
        self.finishedSyncToken = nil
        self.stateToken = nil
        lock.unlock()

        if let finishedSyncToken { cloudSync?.removeFinishedSyncHandler(finishedSyncToken) }
        if let stateToken { cloudSync?.removeStateChangedHandler(stateToken) }
        continuation.resume(with: result)
    }

    private static func mapNotAvailable(
        _ reason: CloudCurrentState.NotAvailableReason
    ) -> BackupSyncError {
        switch reason {
        case .noAccount, .restricted, .disabledByUser, .useriCloudProblem, .other:
            return .iCloudUnavailable
        case .overQuota:
            return .server(underlying: NSError(
                domain: "CloudSync",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "iCloud quota exceeded"]
            ))
        case .schemaNotSupported(let v):
            return .schemaNotSupported(version: v)
        case .incorrectEncryption:
            return .passwordChanged
        case .syncNotAllowed:
            return .limitDevicesReached
        case .error(let err):
            let underlying: any Error & Sendable = err
                ?? NSError(domain: "CloudSync", code: -2)
            return .server(underlying: underlying)
        }
    }
}
