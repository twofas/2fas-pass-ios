// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import CoreData
import Common

extension PasswordCachedEntity {
    @nonobjc static func fetchRequest() -> NSFetchRequest<PasswordCachedEntity> {
        NSFetchRequest<PasswordCachedEntity>(entityName: "PasswordCachedEntity")
    }
    
    @NSManaged var passwordID: PasswordID
    
    @NSManaged var name: Data?
    @NSManaged var username: Data?
    @NSManaged var password: Data?
    @NSManaged var notes: Data?
    
    @NSManaged var creationDate: Date
    @NSManaged var modificationDate: Date
    
    @NSManaged var iconType: String
    @NSManaged var iconCustomURL: Data?
    @NSManaged var iconDomain: Data?
    @NSManaged var labelTitle: Data?
    @NSManaged var labelColor: String?
    
    @NSManaged var isTrashed: Bool
    @NSManaged var trashingDate: Date?
    
    @NSManaged var level: String
    
    @NSManaged var uris: Data?
    @NSManaged var urisMatching: [String]?
    
    @NSManaged var vaultID: VaultID
    
    @NSManaged var metadata: Data
}

extension PasswordCachedEntity: Identifiable {}

extension PasswordCachedEntity {
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
                    return PasswordTrashedStatus.yes(trashingDate: trashingDate)
                }
                return .no
            }(),
            protectionLevel: PasswordProtectionLevel(level: level),
            vaultID: vaultID,
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
            tagIds: nil
        )
    }
}
