// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common

public protocol MigrationInteracting {
    func migrateIfNeeded()
    
    func requiresReencryptionMigration() -> Bool
    func performReencryptionMigration()
}

final class MigrationInteractor: MigrationInteracting {
    
    private let mainRepository: MainRepository
    
    init(mainRepository: MainRepository) {
        self.mainRepository = mainRepository
    }
    
    func requiresReencryptionMigration() -> Bool {
        mainRepository.requiresReencryptionMigration()
    }
    
    func performReencryptionMigration() {
        Log("Start migration with re-encryption", module: .migration, severity: .info)
        mainRepository.loadEncryptedStoreWithReencryptionMigration()
        Log("Finish migration with re-encryption", module: .migration, severity: .info)
    }
    
    func migrateIfNeeded() {
        let appVersion = mainRepository.currentAppVersion
        
        if mainRepository.lastKnownAppVersion == nil { // Below 1.1.0 or first app run
            if mainRepository.isMainAppProcess {
                Log("Start app migration to \(appVersion, privacy: .public)", module: .migration, severity: .info)
                mainRepository.removeOldStoreLogs()
                Log("Finish app migration to \(appVersion, privacy: .public)", module: .migration, severity: .info)
            }
        } else {
            Log("Already migrated for \(appVersion, privacy: .public) version", module: .migration, severity: .info)
        }
        
        mainRepository.setLastKnownAppVersion(appVersion)
    }
}
