// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common
import Backup

/// Ad-hoc reads (and an iCloud delete) for the vault-recovery flow, run before any config is
/// registered. Distinct from `BackupSyncConfigsInteracting` (CRUD + connection probe before
/// persistence) because the audience is recovery UI specifically: the user picks a backend,
/// we read what's there without persisting anything, they pick a vault, we download it, and
/// only after a successful import does any config get registered. Reads the installed
/// `BackupSyncContainer` off `MainRepository` and forwards.
///
/// Two backend shapes coexist here:
/// - **File-based** (WebDAV today; S3 would be a paired overload): `fetchIndex(_:)` +
///   `fetchVault(vaultID:_:)` against typed `Config` values.
/// - **iCloud**: `listICloudVaultsToRecover()` + `deleteICloudVault(id:)`. No `Config` (auth
///   is identity-based), no `BackupIndex` (CloudKit records, separate state machine), and
///   it's the only backend whose recovery surface includes deletion.
public protocol BackupSyncRecoveryInteracting: AnyObject {
    /// Recovery step 1 (file-based): fetch the remote index for an unregistered WebDAV config
    /// and decode it inside the container. Surfaces transport vs. corrupt-index failures
    /// separately so the UI can render distinct error states ("no backup at this URL" vs.
    /// "the index file is damaged").
    func fetchIndex(_ config: BackupWebDAVConfig) async throws(BackupIndexFetchError) -> BackupIndex

    /// Recovery step 2 (file-based): download and decode the vault blob the user picked from
    /// the index. Decoding happens inside the container via `ExchangeVaultVersioned`'s custom
    /// `Decodable` impl; the typed `BackupVaultFetchError` lets the UI distinguish transport
    /// failure, "schema too new for this build," and corrupt-file outcomes.
    func fetchVault(vaultID: UUID, _ config: BackupWebDAVConfig) async throws(BackupVaultFetchError) -> ExchangeVaultVersioned

    /// iCloud counterpart to file-based `fetchIndex`: lists vaults the signed-in iCloud
    /// account has previously backed up. Empty array means the account is reachable but has
    /// no backed-up vaults.
    func listICloudVaultsToRecover() async throws -> [VaultRawData]

    /// Deletes the CloudKit zone backing the vault with `id`. Drives swipe-to-delete in the
    /// iCloud recovery picker. No file-based equivalent — WebDAV/S3 don't expose deletion
    /// from the recovery flow.
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

    func fetchVault(vaultID: UUID, _ config: BackupWebDAVConfig) async throws(BackupVaultFetchError) -> ExchangeVaultVersioned {
        try await mainRepository.backupSyncContainer.fetchVault(vaultID: vaultID, config: config)
    }

    func listICloudVaultsToRecover() async throws -> [VaultRawData] {
        try await mainRepository.backupSyncContainer.listICloudVaultsToRecover()
    }

    func deleteICloudVault(id: VaultID) async throws {
        try await mainRepository.backupSyncContainer.deleteICloudVault(id: id)
    }
}
