// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import CoreData
import Common

extension PasswordEncryptedEntity {
    @nonobjc static func fetchRequest() -> NSFetchRequest<PasswordEncryptedEntity> {
        NSFetchRequest<PasswordEncryptedEntity>(entityName: "PasswordEncryptedEntity")
    }
    
    @NSManaged var passwordID: PasswordID
    
    @NSManaged var name: Data?
    @NSManaged var username: Data?
    @NSManaged var password: Data?
    @NSManaged var notes: Data?
    
    @NSManaged var creationDate: Date
    @NSManaged var modificationDate: Date
    
    @NSManaged var iconType: String
    @NSManaged var iconFile: Data?
    @NSManaged var iconCustomURL: Data?
    @NSManaged var iconDomain: Data?
    @NSManaged var labelTitle: Data?
    @NSManaged var labelColor: String?
    
    @NSManaged var isTrashed: Bool
    @NSManaged var trashingDate: Date?
    
    @NSManaged var level: String
    
    @NSManaged var uris: Data?
    @NSManaged var urisNormalized: Data?
    @NSManaged var urisMatching: [String]?
    @NSManaged var urisNormalizedExtension: [String]?
    @NSManaged var tagIds: [ItemTagID]?
    
    @NSManaged var vault: VaultEncryptedEntity
}

extension PasswordEncryptedEntity: Identifiable {}

extension PasswordEncryptedEntity {
    func toData() -> PasswordEncryptedData {
        PasswordEncryptedData(
            passwordID: passwordID,
            name: name,
            username: username,
            password: password,
            notes: notes,
            creationDate: creationDate,
            modificationDate: modificationDate,
            iconType: PasswordEncryptedIconType(
                iconType: iconType,
                iconDomain: iconDomain,
                iconCustomURL: iconCustomURL,
                labelTitle: labelTitle,
                labelColor: UIColor(hexString: labelColor)
            ),
            trashedStatus: {
                if isTrashed, let trashingDate {
                    return ItemTrashedStatus.yes(trashingDate: trashingDate)
                }
                return .no
            }(),
            protectionLevel: ItemProtectionLevel(level: level),
            vaultID: vault.vaultID,
            uris: { () -> PasswordEncryptedURIs? in
                guard let uris, let urisMatching else { return nil }
                let match: [PasswordURI.Match] = urisMatching.map({ value in
                    if let match = PasswordURI.Match(rawValue: value) {
                        return match
                    }
                    return .domain
                })
                return .init(uris: uris, match: match)
            }(),
            tagIds: tagIds
        )
    }
}
