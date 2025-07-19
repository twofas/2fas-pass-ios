// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

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
        mainRepository.loadEncryptedStoreWithReencryptionMigration()
    }
    
    func migrateIfNeeded() {
        let appVersion = mainRepository.currentAppVersion
        
        if mainRepository.lastKnownAppVersion == nil { // Below 1.1.0 or first app run
            mainRepository.removeAllLogs()
        }
        mainRepository.setLastKnownAppVersion(appVersion)
    }
}
