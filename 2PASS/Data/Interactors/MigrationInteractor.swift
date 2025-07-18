// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

public protocol MigrationInteracting {
    func shouldMigrate() -> Bool
    func migrate()
}

final class MigrationInteractor: MigrationInteracting {
    
    private let mainRepository: MainRepository
    
    init(mainRepository: MainRepository) {
        self.mainRepository = mainRepository
    }
    
    func shouldMigrate() -> Bool {
        mainRepository.requiresReencryptionMigration()
    }
    
    func migrate() {
        mainRepository.loadEncryptedStoreWithReencryptionMigration()
    }
}
