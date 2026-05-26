// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common

public protocol MigrationInteracting {
    func migrateIfNeeded()
    func migrateStorageIfNeeded()

    func requiresReencryptionMigration() -> Bool
    
    @MainActor
    func loadStoreWithReencryptionMigration() async -> Bool
}

final class MigrationInteractor: MigrationInteracting {

    private let mainRepository: MainRepository
    private let tagInteractor: TagInteracting

    init(mainRepository: MainRepository, tagInteractor: TagInteracting) {
        self.mainRepository = mainRepository
        self.tagInteractor = tagInteractor
    }
    
    func requiresReencryptionMigration() -> Bool {
        mainRepository.requiresReencryptionMigration()
    }
    
    @MainActor
    func loadStoreWithReencryptionMigration() async -> Bool {
        await withCheckedContinuation { continuation in
            Log("Start migration with re-encryption", module: .migration, severity: .info)
            mainRepository.loadEncryptedStoreWithReencryptionMigration { success in
                Log("Finish migration with re-encryption", module: .migration, severity: .info)
                continuation.resume(returning: success)
            }
        }
    }
    
    func migrateIfNeeded() {
        let appVersion = mainRepository.currentAppVersion
        let lastKnownAppVersion = mainRepository.lastKnownAppVersion

        guard mainRepository.isMainAppProcess else {
            return
        }
        
        if lastKnownAppVersion == nil { // Below 1.1.0 or first app run
            Log("Start app migration to \(appVersion, privacy: .public)", module: .migration, severity: .info)
            mainRepository.removeOldStoreLogs()
            Log("Finish app migration to \(appVersion, privacy: .public)", module: .migration, severity: .info)
        }

        if lastKnownAppVersion?.compare("1.9.0", options: .numeric) == .orderedAscending {
            mainRepository.migrateLegacyBackupConfigs()
        }
    }

    func migrateStorageIfNeeded() {
        let appVersion = mainRepository.currentAppVersion
        let lastKnownAppVersion = mainRepository.lastKnownAppVersion

        if lastKnownAppVersion?.compare("1.5.0", options: .numeric) == .orderedAscending {
            tagInteractor.migrateTagColors()
        }
        
        if lastKnownAppVersion?.compare("1.5.2", options: .numeric) == .orderedAscending {
            tagInteractor.removeDuplicatedEncryptedTags()
        }
        
        if lastKnownAppVersion?.compare("1.7.0", options: .numeric) == .orderedAscending || lastKnownAppVersion == nil {
            mainRepository.migrateLegacyValuesToSharedDefaults()
        }

        if lastKnownAppVersion?.compare("1.8.0", options: .numeric) == .orderedAscending {
            mainRepository.removeDuplicatedDeletedItems()
        }

        if lastKnownAppVersion?.compare("1.9.0", options: .numeric) == .orderedAscending {
            for vault in mainRepository.listEncryptedVaults() {
                mainRepository.backfillVaultContentModificationDate(vaultID: vault.vaultID)
            }
        }

        mainRepository.saveEncryptedStorage()

        mainRepository.setLastKnownAppVersion(appVersion)
    }
}
