// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import CoreData
import Common

extension PasswordEntity {
    @nonobjc static func fetchRequest() -> NSFetchRequest<PasswordEntity> {
        NSFetchRequest<PasswordEntity>(entityName: entityName)
    }
    
    @NSManaged var passwordID: PasswordID

    @NSManaged var name: String?
    @NSManaged var username: String?
    @NSManaged var password: Data?
    @NSManaged var notes: String?

    @NSManaged var creationDate: Date
    @NSManaged var modificationDate: Date

    @NSManaged var iconType: String
    @NSManaged var iconFile: Data?
    @NSManaged var iconCustomURL: URL?
    @NSManaged var iconDomain: String?
    @NSManaged var labelTitle: String?
    @NSManaged var labelColor: String?

    @NSManaged var isTrashed: Bool
    @NSManaged var trashingDate: Date?
    
    @NSManaged var level: String
    
    @NSManaged var uris: [String]?
    @NSManaged var urisMatching: [String]?
    @NSManaged var tagIds: [ItemTagID]?
}

extension PasswordEntity: Identifiable {}

extension PasswordEntity {
    func toData() -> PasswordData {
        PasswordData(
            passwordID: passwordID,
            name: name,
            username: username,
            password: password,
            notes: notes,
            creationDate: creationDate,
            modificationDate: modificationDate,
            iconType: PasswordIconType(
                iconType: iconType,
                iconDomain: iconDomain,
                iconCustomURL: iconCustomURL,
                labelTitle: labelTitle,
                labelColor: labelColor
            ),
            trashedStatus: {
                if isTrashed, let trashingDate {
                    return .yes(trashingDate: trashingDate)
                }
                return .no
            }(),
            protectionLevel: ItemProtectionLevel(level: level),
            uris: { () -> [PasswordURI]? in
                guard let uris else { return nil }
                return uris.enumerated().map { index, uri in
                    let match: PasswordURI.Match = {
                        if let value = urisMatching?[safe: index], let match = PasswordURI.Match(rawValue: value) {
                            return match
                        }
                        return .domain
                    }()
                    return .init(uri: uri, match: match)
                }
            }(),
            tagIds: tagIds
        )
    }
}
