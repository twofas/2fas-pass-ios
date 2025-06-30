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
        name: String,
        trustedKey: Data,
        createdAt: Date,
        updatedAt: Date,
        isEmpty: Bool
    ) {
        self.vaultID = vaultID
        self.name = name
        self.trustedKey = trustedKey
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isEmpty = isEmpty
    }
    
    public let vaultID: VaultID
    public let name: String
    public let trustedKey: Data
    public let createdAt: Date
    public let updatedAt: Date
    public let isEmpty: Bool
}
