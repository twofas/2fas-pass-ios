// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common
import Backup

/// Ad-hoc reads for the vault-recovery flow, run against unregistered credentials. Distinct
/// from `BackupSyncConfigsInteracting` (CRUD + connection probe before persistence) because
/// the audience is recovery UI specifically: the user types URL / S3 credentials, we read
/// the remote index without persisting anything, they pick a vault, we download it, and only
/// after a successful import does any config get registered. Reads the installed
/// `BackupSyncContainer` off `MainRepository` and forwards. Currently WebDAV-only; an S3
/// recovery flow would add a paired S3 overload.
public protocol BackupSyncRecoveryInteracting: AnyObject {
    /// Recovery step 1: fetch the remote index for an unregistered WebDAV config and decode
    /// it inside the container. Surfaces transport vs. corrupt-index failures separately so
    /// the UI can render distinct error states ("no backup at this URL" vs. "the index file
    /// is damaged").
    func fetchIndex(_ config: BackupWebDAVConfig) async throws(BackupIndexFetchError) -> BackupIndex

    /// Recovery step 2: download and decode the vault blob the user picked from the index.
    /// Decoding happens inside the container via `ExchangeVaultVersioned`'s custom
    /// `Decodable` impl; the typed `BackupVaultFetchError` lets the UI distinguish transport
    /// failure, "schema too new for this build," and corrupt-file outcomes.
    func fetchVault(vaultID: UUID, _ config: BackupWebDAVConfig) async throws(BackupVaultFetchError) -> ExchangeVaultVersioned
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
}
