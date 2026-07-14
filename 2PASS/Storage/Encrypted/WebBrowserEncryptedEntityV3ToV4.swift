//
//  WebBrowserEncryptedEntityV3ToV4.swift
//  2PASS
//
//  Created by Maciej Szewczyk on 08/04/2026.
//  Copyright © 2026 Two Factor Authentication Service, Inc. All rights reserved.
//

import CoreData
import Common

@objc
final class WebBrowserEncryptedEntityV3ToV4: NSEntityMigrationPolicy {

    enum WebBrowserKeys: String {
        case extensionName
        case name
        case publicKey
        case version
        case nextSessionId
    }

    private static let requiredEncryptedKeys: [WebBrowserKeys] = [.extensionName, .name, .publicKey, .version]

    let migrationController = MigrationController.current

    override func createDestinationInstances(
        forSource sInstance: NSManagedObject,
        in mapping: NSEntityMapping,
        manager: NSMigrationManager
    ) throws {
        try super.createDestinationInstances(forSource: sInstance, in: mapping, manager: manager)

        Log("Migration - WebBrowserEncryptedEntity V3 → V4", module: .storage)

        guard let destination = manager.destinationInstances(
            forEntityMappingName: mapping.name,
            sourceInstances: [sInstance]
        ).first else {
            throw MigrationError.missingDestinationInstance
        }

        guard let migrationController else {
            throw MigrationError.missingMigrationController
        }

        for key in Self.requiredEncryptedKeys {
            guard let cipher = sInstance.primitiveValue(forKey: key.rawValue) as? Data else {
                throw MigrationError.missingSourceValue(key: key.rawValue)
            }
            guard let plain = migrationController.decrypt(cipher, using: .appKey) else {
                throw MigrationError.decryptionFailed
            }
            guard let reencrypted = migrationController.encrypt(plain, using: .metadataKey) else {
                throw MigrationError.encryptionFailed
            }
            destination.setValue(reencrypted, forKey: key.rawValue)
        }

        if let cipher = sInstance.primitiveValue(forKey: WebBrowserKeys.nextSessionId.rawValue) as? Data {
            guard let plain = migrationController.decrypt(cipher, using: .appKey) else {
                throw MigrationError.decryptionFailed
            }
            guard let reencrypted = migrationController.encrypt(plain, using: .metadataKey) else {
                throw MigrationError.encryptionFailed
            }
            destination.setValue(reencrypted, forKey: WebBrowserKeys.nextSessionId.rawValue)
        }
    }
}
