// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import CoreData
import Common

@objc
final class PasswordEncryptedEntityToItemEncryptedEntityPolicy: NSEntityMigrationPolicy {
    
    let migrationController = MigrationController.current!
    
    enum PasswordKeys: String {
        case vault
        case level
        case name
        case username
        case notes
        case password
        case iconType
        case iconCustomURL
        case iconDomain
        case labelColor
        case labelTitle
        case urisMatching
        case uris
    }
    
    enum ItemsKeys: String {
        case contentVersion
        case contentType
        case content
    }
    
    enum VaultKeys: String {
        case vaultID
    }
    
    override func createDestinationInstances(forSource sInstance: NSManagedObject, in mapping: NSEntityMapping, manager: NSMigrationManager) throws {
        try super.createDestinationInstances(forSource: sInstance, in: mapping, manager: manager)

        Log("Migration - createDestinationInstances", module: .storage)

        guard let destination = manager.destinationInstances(forEntityMappingName: mapping.name, sourceInstances: [sInstance]).first else {
            throw MigrationError.missingDestinationInstance
        }

        guard let protectionLevelValue = sInstance.primitiveValue(forKey: PasswordKeys.level.rawValue) as? String else {
            throw MigrationError.missingSourceValue(key: PasswordKeys.level.rawValue)
        }
        
        if let vault = sInstance.value(forKey: PasswordKeys.vault.rawValue) as? NSManagedObject,
           let vaultID = vault.primitiveValue(forKey: VaultKeys.vaultID.rawValue) as? UUID {
            migrationController.setupKeys(vaultID: vaultID)
        }
        
        let protectionLevel = ItemProtectionLevel(level: protectionLevelValue)

        let name = {
            if let nameEnc = sInstance.primitiveValue(forKey: PasswordKeys.name.rawValue) as? Data, let nameData = migrationController.decrypt(nameEnc, protectionLevel: protectionLevel) {
                return String(data: nameData, encoding: .utf8)
            }
            return nil
        }()
        
        let username = {
            if let usernameEnc = sInstance.primitiveValue(forKey: PasswordKeys.username.rawValue) as? Data, let usernameData = migrationController.decrypt(usernameEnc, protectionLevel: protectionLevel) {
                return String(data: usernameData, encoding: .utf8)
            }
            return nil
        }()
        
        let notes = {
            if let notesEnc = sInstance.primitiveValue(forKey: PasswordKeys.notes.rawValue) as? Data, let notesData = migrationController.decrypt(notesEnc, protectionLevel: protectionLevel) {
                return String(data: notesData, encoding: .utf8)
            }
            return nil
        }()
        
        
        let iconType: PasswordIconType = {
            if let iconType = sInstance.primitiveValue(forKey: PasswordKeys.iconType.rawValue) as? String {
                let domain: String? = {
                    guard let domainDataEnc = sInstance.primitiveValue(forKey: PasswordKeys.iconDomain.rawValue) as? Data,
                          let domainData = migrationController.decrypt(domainDataEnc, protectionLevel: protectionLevel) else {
                        return nil
                    }
                    return String(data: domainData, encoding: .utf8)
                }()
                
                let customURL: URL? = {
                    guard let cutomURLDataEnc = sInstance.primitiveValue(forKey: PasswordKeys.iconCustomURL.rawValue) as? Data,
                          let customURLData = migrationController.decrypt(cutomURLDataEnc, protectionLevel: protectionLevel),
                          let customURLString = String(data: customURLData, encoding: .utf8) else {
                        return nil
                    }
                    return URL(string: customURLString)
                }()
                
                let labelTitle: String? = {
                    guard let labelTitleEnc = sInstance.primitiveValue(forKey: PasswordKeys.labelTitle.rawValue) as? Data,
                          let labelTitleData = migrationController.decrypt(labelTitleEnc, protectionLevel: protectionLevel) else {
                        return nil
                    }
                    return String(data: labelTitleData, encoding: .utf8)
                }()
                
                let labelColor = sInstance.primitiveValue(forKey: PasswordKeys.labelColor.rawValue) as? String
                
                return PasswordIconType(
                    iconType: iconType,
                    iconDomain: domain,
                    iconCustomURL: customURL,
                    labelTitle: labelTitle,
                    labelColor: labelColor
                )
            }
            return .default
        }()
        
        let uris: [PasswordURI]? = {
            guard let urisEnc = sInstance.primitiveValue(forKey: PasswordKeys.uris.rawValue) as? Data,
                  let urisData = migrationController.decrypt(urisEnc, protectionLevel: protectionLevel),
                  let uris = try? JSONDecoder().decode([String].self, from: urisData) else {
                return nil
            }
            guard let uriMatching = sInstance.primitiveValue(forKey: PasswordKeys.urisMatching.rawValue) as? [String] else {
                return nil
            }
            return uris.indices.map {
                PasswordURI(uri: uris[$0], match: .init(rawValue: uriMatching[$0]) ?? .domain)
            }
        }()
        
        let content = PasswordItemContent(
            name: name,
            username: username,
            password: sInstance.primitiveValue(forKey: PasswordKeys.password.rawValue) as? Data,
            notes: notes,
            iconType: iconType,
            uris: uris
        )
        
        let contentData = try JSONEncoder().encode(content)
        let contentDataEnc = migrationController.encrypt(contentData, protectionLevel: protectionLevel)
        
        destination.setValue(1, forKey: ItemsKeys.contentVersion.rawValue)
        destination.setValue(ItemContentType.login.rawValue, forKey: ItemsKeys.contentType.rawValue)
        destination.setValue(contentDataEnc, forKey: ItemsKeys.content.rawValue)
    }
}
