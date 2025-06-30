// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

public struct PasswordEncryptedData: Hashable, Identifiable {
    public var id: UUID {
        passwordID
    }
    
    public let passwordID: PasswordID
    public let name: Data?
    public let username: Data?
    public let password: Data?
    public let notes: Data?
    public let creationDate: Date
    public let modificationDate: Date
    public let iconType: PasswordEncryptedIconType
    public let trashedStatus: PasswordTrashedStatus
    public let protectionLevel: PasswordProtectionLevel
    public let vaultID: VaultID
    public let uris: PasswordEncryptedURIs?
    public let tagIds: [ItemTagID]?
    
    public init(
        passwordID: PasswordID,
        name: Data?,
        username: Data?,
        password: Data?,
        notes: Data?,
        creationDate: Date,
        modificationDate: Date,
        iconType: PasswordEncryptedIconType,
        trashedStatus: PasswordTrashedStatus,
        protectionLevel: PasswordProtectionLevel,
        vaultID: VaultID,
        uris: PasswordEncryptedURIs?,
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
        self.vaultID = vaultID
        self.uris = uris
        self.tagIds = tagIds
    }
}
