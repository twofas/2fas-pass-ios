// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common
import Backup

/// Ad-hoc reads (and an iCloud delete) for the vault-recovery flow, run before any config
/// is registered. Distinct from `BackupSyncConfigsInteracting` (CRUD + pre-persistence
/// probe): here the user picks a backend, reads what's there, picks a vault, downloads it,
/// and only after a successful import does any config get registered.
public protocol BackupSyncRecoveryInteracting: AnyObject {
    /// Fetch the remote index for an unregistered config. Transport vs. corrupt-index
    /// failures are surfaced separately via `BackupIndexFetchError`.
    func fetchIndex(_ config: BackupWebDAVConfig) async throws(BackupIndexFetchError) -> BackupIndex
    func fetchIndex(_ config: S3ServiceConfig) async throws(BackupIndexFetchError) -> BackupIndex

    /// Download and decode the vault blob the user picked. `BackupVaultFetchError`
    /// distinguishes transport, schema-too-new, and corrupt-file outcomes.
    func fetchVault(vaultID: UUID, _ config: BackupWebDAVConfig) async throws(BackupVaultFetchError) -> ExchangeVaultVersioned
    func fetchVault(vaultID: UUID, _ config: S3ServiceConfig) async throws(BackupVaultFetchError) -> ExchangeVaultVersioned

    /// Lists vaults the signed-in iCloud account has previously backed up. Empty means the
    /// account is reachable but has no backups. iCloud is identity-based — no `Config`.
    func listICloudVaultsToRecover() async throws -> [VaultRawData]

    /// Deletes the CloudKit zone backing the vault. Drives swipe-to-delete in the iCloud
    /// recovery picker; no file-based equivalent.
    func deleteICloudVault(id: VaultID) async throws
}

final class BackupSyncRecoveryInteractor: BackupSyncRecoveryInteracting {
    private let mainRepository: MainRepository

    init(mainRepository: MainRepository) {
        self.mainRepository = mainRepository
    }

    func fetchIndex(_ config: BackupWebDAVConfig) async throws(BackupIndexFetchError) -> BackupIndex {
        try await mainRepository.backupSyncContainer.fetchIndex(config: config)
    }

    func fetchIndex(_ config: S3ServiceConfig) async throws(BackupIndexFetchError) -> BackupIndex {
        try await mainRepository.backupSyncContainer.fetchIndex(config: config)
    }

    func fetchVault(vaultID: UUID, _ config: BackupWebDAVConfig) async throws(BackupVaultFetchError) -> ExchangeVaultVersioned {
        try await mainRepository.backupSyncContainer.fetchVault(vaultID: vaultID, config: config)
    }

    func fetchVault(vaultID: UUID, _ config: S3ServiceConfig) async throws(BackupVaultFetchError) -> ExchangeVaultVersioned {
        try await mainRepository.backupSyncContainer.fetchVault(vaultID: vaultID, config: config)
    }

    func listICloudVaultsToRecover() async throws -> [VaultRawData] {
        try await mainRepository.backupSyncContainer.listICloudVaultsToRecover()
    }

    func deleteICloudVault(id: VaultID) async throws {
        try await mainRepository.backupSyncContainer.deleteICloudVault(id: id)
    }
}
