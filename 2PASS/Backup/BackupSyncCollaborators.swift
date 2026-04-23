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
        includeDeleted: Bool
    ) async throws(BackupVaultExportError) -> ExchangeVault

#if DEBUG
    func prepareDecryptedExport(
        includeDeleted: Bool
    ) async throws(BackupVaultExportError) -> ExchangeVault
#endif
}

public protocol BackupSyncContextProviding: Sendable {
    var deviceName: String { get }
    var deviceID: UUID { get }
    
    var vaultID: UUID { get }
    var vaultCreatedAt: Int { get }
    var seedHash: String { get }
    
    var lastSyncTimestamp: Int? { get }
    var hasLocalChanges: Bool { get }
    var allowsMultiDeviceSync: Bool { get }
    
#if DEBUG
    var shouldWriteDecryptedCopy: Bool { get }
#endif
    
    func clearHasLocalChanges() async
}
