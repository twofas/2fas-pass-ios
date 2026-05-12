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
    public func syncOnce(allowingAnyDeviceId: Bool) async throws(BackupSyncError) -> BackupSyncOutcome {
        do {
            return try await syncOncePass(allowingAnyDeviceId: allowingAnyDeviceId)
        } catch let err as BackupSyncError {
            throw err
        } catch {
            throw BackupSyncError.unexpected("CloudSync.syncOnce: \(error)")
        }
    }

    private func syncOncePass(allowingAnyDeviceId: Bool) async throws -> BackupSyncOutcome {
        try Task.checkCancellation()

        let holder = BridgeHolder()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let bridge = Bridge(cloudSync: self, continuation: continuation)
                holder.set(bridge)
                bridge.start(allowingAnyDeviceId: allowingAnyDeviceId)
            }
        } onCancel: {
            // Resume the awaiting continuation with `.cancelled` so the cancel button has an
            // observable effect. The underlying CloudKit op keeps running to completion in the
            // background — CloudKit doesn't surface a cancellation primitive at this layer —
            // but the session's `.finished` event fires immediately, `clearSyncSlot()` runs,
            // and the UI's `isSyncing` flag flips off without waiting for CloudKit to settle.
            holder.cancel()
        }
    }
}

/// Carries the per-call `Bridge` instance across the `withTaskCancellationHandler` boundary so
/// `onCancel` can reach it. The bridge is created inside the continuation closure (it needs the
/// continuation to construct), but `onCancel` runs in a separate scope and would otherwise have
/// no way to signal it.
///
/// Race-safe in both directions: if `cancel()` lands before `set(_:)` (task cancelled while the
/// continuation closure is still running), the `cancelled` flag is sticky and the just-set
/// bridge is cancelled immediately.
private final class BridgeHolder: @unchecked Sendable {
    private let lock = NSLock()
    private var bridge: Bridge?
    private var cancelled = false

    func set(_ bridge: Bridge) {
        lock.lock()
        let alreadyCancelled = cancelled
        if !alreadyCancelled {
            self.bridge = bridge
        }
        lock.unlock()
        if alreadyCancelled {
            bridge.cancel()
        }
    }

    func cancel() {
        lock.lock()
        let bridge = self.bridge
        cancelled = true
        lock.unlock()
        bridge?.cancel()
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

    init(cloudSync: CloudSync, continuation: CheckedContinuation<BackupSyncOutcome, Error>) {
        self.cloudSync = cloudSync
        self.continuation = continuation
    }

    /// Resumes the awaiting continuation with `.cancelled`. Idempotent and safe to race with
    /// the natural completion path — `resume(_:)` no-ops on second call. The underlying
    /// CloudKit operation keeps running in the background; this only releases the awaiter.
    func cancel() {
        resume(.failure(BackupSyncError.cancelled))
    }

    func start(allowingAnyDeviceId: Bool) {
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

        if allowingAnyDeviceId {
            // CloudKit analogue of the file-based path's `allowingAnyDeviceId || context.allowsMultiDeviceSync`
            // gate: flag the merge handler so a deviceID conflict resolves in favour of this
            // device. `isTakingOverVault` short-circuits the multi-device-sync entitlement check
            // at the use-site (`MergeHandler.applyChanges`'s `isMultiDeviceSyncEnabled || isTakingOverVault`),
            // so a Free-tier user can still complete an explicit "take over" intent
            // (post-recovery, the recovery flow marks `awaitingDeviceRegistration` for the
            // iCloud config, which lands here as `allowingAnyDeviceId: true`).
            cloudSync.setTakingOverVault(true)
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
