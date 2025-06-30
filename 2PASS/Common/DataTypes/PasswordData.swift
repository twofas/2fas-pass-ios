// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

public struct PasswordData: Hashable, Identifiable {
    public var id: UUID {
        passwordID
    }
    
    public let passwordID: PasswordID
    public let name: String?
    public let username: String?
    public let password: Data?
    public let notes: String?
    public let creationDate: Date
    public let modificationDate: Date
    public let iconType: PasswordIconType
    public let trashedStatus: PasswordTrashedStatus
    public let protectionLevel: PasswordProtectionLevel
    public let uris: [PasswordURI]?
    public let tagIds: [ItemTagID]?
    
    public init(
        passwordID: PasswordID,
        name: String?,
        username: String?,
        password: Data?,
        notes: String?,
        creationDate: Date,
        modificationDate: Date,
        iconType: PasswordIconType,
        trashedStatus: PasswordTrashedStatus,
        protectionLevel: PasswordProtectionLevel,
        uris: [PasswordURI]?,
        tagIds: [ItemTagID]?
    ) {
        self.passwordID = passwordID
        self.name = name
        self.username = username
        self.password = password
        self.notes = notes
        self.creationDate = creationDate
        self.modificationDate = modificationDate
        self.iconType = iconType
        self.trashedStatus = trashedStatus
        self.protectionLevel = protectionLevel
        self.uris = uris
        self.tagIds = tagIds
    }
}

public extension PasswordData {
    func updatePassword(_ newPassword: Data?, using newModificationDate: Date) -> PasswordData {
        .init(
            passwordID: passwordID,
            name: name,
            username: username,
            password: newPassword,
            notes: notes,
            creationDate: creationDate,
            modificationDate: newModificationDate,
            iconType: iconType,
            trashedStatus: trashedStatus,
            protectionLevel: protectionLevel,
            uris: uris,
            tagIds: tagIds
        )
    }
    
    var isTrashed: Bool {
        switch trashedStatus {
        case .no: false
        case .yes: true
        }
    }
}
