// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common
import Backup

/// Pre-registration reads for vault recovery — config is only persisted after a successful
/// import.
public protocol BackupSyncRecoveryInteracting: AnyObject {
    func fetchIndex(_ config: BackupWebDAVConfig) async throws(BackupIndexFetchError) -> BackupIndex
    func fetchIndex(_ config: S3ServiceConfig) async throws(BackupIndexFetchError) -> BackupIndex

    func fetchVault(vaultID: UUID, _ config: BackupWebDAVConfig) async throws(BackupVaultFetchError) -> ExchangeVaultVersioned
    func fetchVault(vaultID: UUID, _ config: S3ServiceConfig) async throws(BackupVaultFetchError) -> ExchangeVaultVersioned

    /// Empty means the account is reachable but has no backups.
    func listICloudVaultsToRecover() async throws -> [VaultRawData]

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
