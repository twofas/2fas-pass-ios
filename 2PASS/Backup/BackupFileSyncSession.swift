// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

public final class BackupFileSyncSession: Sendable {

    public let status: AsyncStream<BackupSyncStatus>

    private let statusContinuation: AsyncStream<BackupSyncStatus>.Continuation

    private let service: BackupFileServiceSession
    private let context: BackupSyncContext
    private let vaultExporter: BackupVaultExporting
    private let localMerger: BackupLocalMerging
    private let maxRetries: Int
    private let networkRetryDelay: Duration
    private let serverRetryDelay: Duration

    public init(
        service: BackupFileServiceSession,
        context: BackupSyncContext,
        vaultExporter: BackupVaultExporting,
        localMerger: BackupLocalMerging,
        maxRetries: Int = 3,
        networkRetryDelay: Duration = .seconds(10),
        serverRetryDelay: Duration = .seconds(Config.webDAVLockFileTime)
    ) {
        self.service = service
        self.context = context
        self.vaultExporter = vaultExporter
        self.localMerger = localMerger
        self.maxRetries = max(1, maxRetries)
        self.networkRetryDelay = networkRetryDelay
        self.serverRetryDelay = serverRetryDelay

        let (stream, continuation) = AsyncStream.makeStream(of: BackupSyncStatus.self)
        self.status = stream
        self.statusContinuation = continuation
    }

    deinit {
        statusContinuation.finish()
    }

    /// Runs a full sync attempt, retrying transient errors up to `maxRetries` times.
    /// - Returns: `true` if the sync applied any changes to the local database, `false` otherwise.
    public func sync(overwritingVault: Bool = false) async throws(BackupSyncError) -> Bool {
        emit(.started)

        var attempt = 0
        while true {
            attempt += 1
            do {
                let madeLocalChanges = try await runAttempt(overwritingVault: overwritingVault)
                emit(.succeeded)
                return madeLocalChanges
            } catch let error where error.isTransient && attempt < maxRetries {
                emit(.retrying(reason: "\(error)"))
                do {
                    try await Task.sleep(for: retryDelay(for: error))
                } catch {
                    emit(.failed(.cancelled))
                    throw BackupSyncError.cancelled
                }
                continue
            } catch {
                emit(.failed(error))
                throw error
            }
        }
    }
}

private extension BackupFileSyncSession {

    enum VaultAction {
        case noop
        case needsRemoteMerge
    }

    enum LockVerdict {
        case takeOver
        case waitAndRetry(until: Int)
    }

    func runAttempt(overwritingVault: Bool) async throws(BackupSyncError) -> Bool {
        let currentSyncDate = Date()

        guard let vaultBackup = context.vaultBackup(for: context.vaultID) else {
            throw .unexpected("no vault to sync")
        }
        
        let vaultID = vaultBackup.vaultID

        try checkCancellation()
        let fetchedIndex = try await fetchIndex()

        try checkCancellation()
        let action = try decideAction(for: fetchedIndex, vaultBackup: vaultBackup)
        guard action == .needsRemoteMerge else { return false }

        try checkCancellation()
        try await resolveLock(at: currentSyncDate)

        var madeLocalChanges = false
        if overwritingVault {
            Log("BackupFileSyncSession - overwritingVault requested, skipping remote merge", module: .backup)
        } else {
            try checkCancellation()
            if let remoteVault = try await fetchRemoteVault(vaultID: vaultID) {
                try checkCancellation()
                madeLocalChanges = try await mergeRemoteVault(remoteVault)
            }
        }

        try checkCancellation()
        let exported = try await prepareEncryptedExport(vaultID: vaultID)

        try checkCancellation()
        try await writeExportedVault(encrypted: exported, vaultID: vaultID)

    #if DEBUG
        writeDecryptedCopyIfNeeded(vaultID: vaultID)
    #endif

        try checkCancellation()
        try await writeUpdatedIndex(
            basedOn: fetchedIndex,
            at: currentSyncDate,
            vaultBackup: vaultBackup
        )

        try checkCancellation()
        try await deleteLock()

        await vaultBackup.clearHasLocalChanges()

        return madeLocalChanges
    }

    // MARK: - Steps

    func fetchIndex() async throws(BackupSyncError) -> BackupIndex? {
        Log("BackupFileSyncSession - fetching index", module: .backup)
        do {
            let data = try await service.fetchIndex()
            if let decoded = try? JSONDecoder().decode(BackupIndex.self, from: data) {
                return decoded
            }
            Log("BackupFileSyncSession - index damaged, will overwrite", module: .backup)
            return nil
        } catch let error {
            if case .notFound = error {
                Log("BackupFileSyncSession - no index yet (first sync)", module: .backup)
                return nil
            }
            throw BackupSyncError.from(transport: error)
        }
    }

    func decideAction(for fetchedIndex: BackupIndex?, vaultBackup: VaultBackup) throws(BackupSyncError) -> VaultAction {
        guard let fetchedIndex,
              let matchIndex = fetchedIndex.firstIndex(for: vaultBackup.vaultID, seedHash: vaultBackup.seedHash) else {
            return .needsRemoteMerge
        }

        let entry = fetchedIndex.backups[matchIndex]

        if entry.schemaVersion > Config.webDAVURLSchemaVersion {
            Log("BackupFileSyncSession - remote schema \(entry.schemaVersion) unsupported", module: .backup, severity: .error)
            throw .schemaNotSupported(version: entry.schemaVersion)
        }

        if let lastSync = vaultBackup.lastSyncTimestamp, lastSync == entry.vaultUpdatedAt {
            if vaultBackup.hasLocalChanges {
                Log("BackupFileSyncSession - timestamps match, local changes to push", module: .backup)
                return .needsRemoteMerge
            } else {
                Log("BackupFileSyncSession - timestamps match, no local changes; nothing to do", module: .backup)
                return .noop
            }
        }

        Log("BackupFileSyncSession - timestamps differ (\(vaultBackup.lastSyncTimestamp ?? -1) vs \(entry.vaultUpdatedAt))", module: .backup)
        return .needsRemoteMerge
    }

    func resolveLock(at syncDate: Date) async throws(BackupSyncError) {
        for attempt in 0..<maxRetries {
            let verdict = try await inspectLock()
            switch verdict {
            case .takeOver:
                try await writeLock(at: syncDate)
                return
            case .waitAndRetry(let waitTimestamp):
                Log("BackupFileSyncSession - foreign lock fresh, waiting (attempt \(attempt + 1)/\(maxRetries))", module: .backup)
                let now = Date().exportTimestamp
                let secondsToWait = max(1, waitTimestamp - now)
                do {
                    try await Task.sleep(for: .seconds(secondsToWait))
                } catch {
                    throw BackupSyncError.cancelled
                }
            }
        }
        throw .unexpected("lock contention exceeded max retries")
    }

    func inspectLock() async throws(BackupSyncError) -> LockVerdict {
        Log("BackupFileSyncSession - inspecting lock", module: .backup)
        do {
            let data = try await service.fetchLock()
            guard let decoded = decodeLock(data) else {
                Log("BackupFileSyncSession - lock damaged, overwriting", module: .backup)
                return .takeOver
            }
            if decoded.deviceId == context.deviceID {
                Log("BackupFileSyncSession - own stale lock from previous sync, overwriting", module: .backup)
                return .takeOver
            }
            let now = Date().exportTimestamp
            let age = now - decoded.timestamp
            let isFresh = decoded.timestamp + Config.webDAVLockFileTime > now || age < 4 * Config.webDAVLockFileTime
            if isFresh {
                let waitUntil = decoded.timestamp + (Config.webDAVLockFileTime * 3) / 2
                return .waitAndRetry(until: waitUntil)
            }
            Log("BackupFileSyncSession - foreign lock stale, overwriting", module: .backup)
            return .takeOver
        } catch let error {
            if case .notFound = error {
                Log("BackupFileSyncSession - no lock present", module: .backup)
                return .takeOver
            }
            throw BackupSyncError.from(transport: error)
        }
    }

    func writeLock(at syncDate: Date) async throws(BackupSyncError) {
        Log("BackupFileSyncSession - writing lock", module: .backup)
        let payload = encodeLock(timestamp: syncDate.exportTimestamp, deviceId: context.deviceID)
        do {
            try await service.writeLock(payload)
        } catch {
            throw BackupSyncError.from(transport: error)
        }
    }

    func fetchRemoteVault(vaultID: UUID) async throws(BackupSyncError) -> ExchangeVaultVersioned? {
        Log("BackupFileSyncSession - fetching remote vault", module: .backup)
        let vaultData: Data
        do {
            vaultData = try await service.fetchVault(vaultID: vaultID)
        } catch let error {
            if case .notFound = error {
                Log("BackupFileSyncSession - no remote vault (first push)", module: .backup)
                return nil
            }
            throw BackupSyncError.from(transport: error)
        }

        do {
            return try JSONDecoder().decode(ExchangeVaultVersioned.self, from: vaultData)
        } catch let error as ExchangeDecodeError {
            throw BackupSyncError.from(decode: error)
        } catch {
            Log("BackupFileSyncSession - remote vault corrupted, will overwrite", module: .backup, severity: .error)
            return nil
        }
    }

    func mergeRemoteVault(_ remoteVault: ExchangeVaultVersioned) async throws(BackupSyncError) -> Bool {
        let remoteItemsCount = switch remoteVault {
        case .v1(let vault): vault.itemsCount
        case .v2(let vault): vault.itemsCount
        }
        Log("BackupFileSyncSession - applying \(remoteItemsCount) remote items to local DB", module: .backup)

        do {
            return try await localMerger.applyRemoteChanges(
                remoteVault,
                allowingAnyDeviceId: context.allowsMultiDeviceSync
            )
        } catch let error {
            throw BackupSyncError.from(merge: error)
        }
    }

    func prepareEncryptedExport(vaultID: UUID) async throws(BackupSyncError) -> Data {
        Log("BackupFileSyncSession - preparing encrypted export", module: .backup)
        let vault: ExchangeVault
        do {
            vault = try await vaultExporter.prepareEncryptedExport(vaultID: vaultID, includeDeleted: true)
        } catch {
            throw BackupSyncError.export(error)
        }
        
        precondition(
            vault.encryption != nil
                && vault.vault.items == nil
                && vault.vault.tags == nil
                && vault.vault.itemsDeleted == nil,
            "\(#function) produced a vault that isn't fully encrypted"
        )
        
        do {
            return try JSONEncoder().encode(vault)
        } catch {
            throw BackupSyncError.unexpected("encode vault: \(error)")
        }
    }

    func writeExportedVault(encrypted: Data, vaultID: UUID) async throws(BackupSyncError) {
        do {
            try await service.writeVault(encrypted, vaultID: vaultID)
            try await service.finalizeVault(vaultID: vaultID)
        } catch {
            throw BackupSyncError.from(transport: error)
        }
    }

#if DEBUG
    func writeDecryptedCopyIfNeeded(vaultID: UUID) {
        guard context.shouldWriteDecryptedCopy else { return }
        Task.detached { [vaultExporter, service] in
            do {
                let vault = try await vaultExporter.prepareDecryptedExport(vaultID: vaultID, includeDeleted: true)
                let plaintext = try JSONEncoder().encode(vault)
                try await service.writeDecryptedVault(plaintext, vaultID: vaultID)
            } catch {
                Log("BackupFileSyncSession - decrypted copy failed: \(error)", module: .backup, severity: .warning)
            }
        }
    }
#endif

    func writeUpdatedIndex(
        basedOn fetchedIndex: BackupIndex?,
        at syncDate: Date,
        vaultBackup: VaultBackup
    ) async throws(BackupSyncError) {
        let index = makeUpdatedIndex(
            basedOn: fetchedIndex,
            at: syncDate,
            vaultBackup: vaultBackup
        )
        let data: Data
        do {
            data = try JSONEncoder().encode(index)
        } catch {
            throw BackupSyncError.unexpected("encode index: \(error)")
        }
        do {
            try await service.writeIndex(data)
        } catch {
            throw BackupSyncError.from(transport: error)
        }
    }

    func deleteLock() async throws(BackupSyncError) {
        do {
            try await service.deleteLock()
        } catch {
            throw BackupSyncError.from(transport: error)
        }
    }

    // MARK: - Helpers (pure)

    func makeUpdatedIndex(
        basedOn fetchedIndex: BackupIndex?,
        at syncDate: Date,
        vaultBackup: VaultBackup
    ) -> BackupIndex {
        let timestamp = syncDate.exportTimestamp
        let entry = BackupIndexEntry(
            seedHashHex: vaultBackup.seedHash,
            vaultId: vaultBackup.vaultID.uuidString.lowercased(),
            vaultCreatedAt: vaultBackup.vaultCreatedAt,
            vaultUpdatedAt: timestamp,
            deviceName: context.deviceName,
            deviceId: context.deviceID,
            schemaVersion: Config.webDAVURLSchemaVersion
        )

        guard let fetchedIndex else {
            return BackupIndex(backups: [entry])
        }

        var entries = fetchedIndex.backups
        if let existing = fetchedIndex.firstIndex(for: vaultBackup.vaultID, seedHash: vaultBackup.seedHash) {
            var updated = entries[existing]
            updated.vaultUpdatedAt = timestamp
            updated.deviceName = context.deviceName
            entries[existing] = updated
        } else {
            entries.append(entry)
        }
        return BackupIndex(backups: entries)
    }

    func encodeLock(timestamp: Int, deviceId: UUID) -> Data {
        struct Payload: Encodable {
            let timestamp: Int
            let deviceId: UUID
        }
        return (try? JSONEncoder().encode(Payload(timestamp: timestamp, deviceId: deviceId))) ?? Data()
    }

    func decodeLock(_ data: Data) -> (timestamp: Int, deviceId: UUID)? {
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let timestamp = object["timestamp"] as? Int,
            let deviceIdString = object["deviceId"] as? String,
            let deviceId = UUID(uuidString: deviceIdString)
        else { return nil }
        return (timestamp, deviceId)
    }

    func retryDelay(for error: BackupSyncError) -> Duration {
        switch error {
        case .network, .invalidResponse:
            return networkRetryDelay
        case .server:
            return serverRetryDelay
        default:
            return serverRetryDelay
        }
    }

    func checkCancellation() throws(BackupSyncError) {
        if Task.isCancelled {
            throw .cancelled
        }
    }

    func emit(_ status: BackupSyncStatus) {
        statusContinuation.yield(status)
    }
}
