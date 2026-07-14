// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

public struct VaultEncryptedData: Hashable, Identifiable {
    public var id: UUID {
        vaultID
    }
    
    public init(
        vaultID: VaultID,
        name: Data,
        trustedKey: Data,
        createdAt: Date,
        updatedAt: Date,
        isEmpty: Bool,
        color: String?,
        icon: String?,
        contentModificationDate: Date? = nil
    ) {
        self.vaultID = vaultID
        self.name = name
        self.trustedKey = trustedKey
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isEmpty = isEmpty
        self.color = color
        self.icon = icon
        self.contentModificationDate = contentModificationDate
    }

    public let vaultID: VaultID
    public let name: Data
    public let trustedKey: Data
    public let createdAt: Date
    public let updatedAt: Date
    public let isEmpty: Bool
    public let color: String?
    public let icon: String?
    public let contentModificationDate: Date?
}
