// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

public enum BackupLocalMergeError: Error, Sendable {
    case errorDecrypting
    case otherDeviceId
    case passwordChanged
    case needsPassword
}

public enum BackupVaultExportError: Error, Sendable {
    case empty
    case encryptionFailed
    case other(String)
}

public protocol BackupLocalMerging: Sendable {
    /// Applies a parsed remote vault to the local database.
    /// - Returns: `true` if any local state was mutated, `false` if the merge was a no-op.
    func applyRemoteChanges(
        _ remoteVault: ExchangeVaultVersioned,
        allowingAnyDeviceId: Bool
    ) async throws(BackupLocalMergeError) -> Bool
}

public protocol BackupVaultExporting: Sendable {
    func prepareEncryptedExport(
        vaultID: UUID,
        includeDeleted: Bool
    ) async throws(BackupVaultExportError) -> ExchangeVault

#if DEBUG
    func prepareDecryptedExport(
        vaultID: UUID,
        includeDeleted: Bool
    ) async throws(BackupVaultExportError) -> ExchangeVault
#endif
}

public protocol BackupSyncContext: Sendable {
    /// `nil` before the device has generated/stored an ID — typically only during very early
    /// setup. Sync attempts must guard for nil and fail fast: locking and index identity both
    /// require a stable device ID, so a sync without one cannot meaningfully participate.
    var deviceID: UUID? { get }
    var deviceName: String { get }
    var allowsMultiDeviceSync: Bool { get }

    /// `nil` when no vault is currently selected (typical between logout and login). Sync
    /// attempts must guard for nil and fail fast: there's nothing to sync without a target vault.
    var vaultID: UUID? { get }
    func vault(for vaultID: UUID) -> VaultEncryptedData?
    func seedHash(for vaultID: UUID) -> String?
    
#if DEBUG
    var shouldWriteDecryptedCopy: Bool { get }
#endif
}
