// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

extension CloudSync {

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
            holder.cancel()
        }
    }
}

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

    func cancel() {
        resume(.failure(BackupSyncError.cancelled))
    }

    func start(allowingAnyDeviceId: Bool) {
        guard let cloudSync else {
            resume(.failure(BackupSyncError.iCloudUnavailable))
            return
        }

        finishedSyncToken = cloudSync.addFinishedSyncHandler { applied in
            self.resume(.success(BackupSyncOutcome(appliedRemoteChanges: applied)))
        }

        stateToken = cloudSync.addStateChangedHandler { state in
            self.evaluateTerminalState(state)
        }

        if isResumed { return }

        if allowingAnyDeviceId {
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
