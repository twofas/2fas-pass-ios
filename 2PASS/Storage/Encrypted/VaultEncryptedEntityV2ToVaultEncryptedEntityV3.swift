//
//  VaultEncryptedEntityV2ToVaultEncryptedEntityV3.swift
//  2PASS
//
//  Created by Maciej Szewczyk on 03/04/2026.
//  Copyright © 2026 Two Factor Authentication Service, Inc. All rights reserved.
//

import CoreData
import Common

@objc
final class VaultEncryptedEntityV2ToVaultEncryptedEntityV3: NSEntityMigrationPolicy {

    let migrationController = MigrationController.current

    override func createDestinationInstances(
        forSource sInstance: NSManagedObject,
        in mapping: NSEntityMapping,
        manager: NSMigrationManager
    ) throws {
        try super.createDestinationInstances(forSource: sInstance, in: mapping, manager: manager)

        Log("Migration - VaultEncryptedEntity V2 → V3", module: .storage)

        guard let destination = manager.destinationInstances(
            forEntityMappingName: mapping.name,
            sourceInstances: [sInstance]
        ).first else {
            throw MigrationError.missingDestinationInstance
        }

        guard let migrationController else {
            throw MigrationError.missingMigrationController
        }

        guard let vaultID = sInstance.primitiveValue(forKey: "vaultID") as? UUID else {
            throw MigrationError.missingSourceValue(key: "vaultID")
        }

        migrationController.setupKeys(vaultID: vaultID)

        guard let plainName = sInstance.primitiveValue(forKey: "name") as? String else {
            throw MigrationError.missingSourceValue(key: "name")
        }

        guard let nameData = plainName.data(using: .utf8),
              let encryptedName = migrationController.encrypt(nameData, protectionLevel: .normal) else {
            throw MigrationError.encryptionFailed
        }

        destination.setValue(encryptedName, forKey: "name")
    }
}
