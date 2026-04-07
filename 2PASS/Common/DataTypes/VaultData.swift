// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

public struct VaultData: Hashable, Identifiable {
    public var id: UUID { vaultID }

    public let vaultID: VaultID
    public let name: String
    public let createdAt: Date
    public let updatedAt: Date
    public let isEmpty: Bool
    public let color: String?
    public let icon: String?

    public init(
        vaultID: VaultID,
        name: String,
        createdAt: Date,
        updatedAt: Date,
        isEmpty: Bool,
        color: String?,
        icon: String?
    ) {
        self.vaultID = vaultID
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isEmpty = isEmpty
        self.color = color
        self.icon = icon
    }
}
