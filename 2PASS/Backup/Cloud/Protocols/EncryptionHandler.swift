// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

public protocol EncryptionHandler: AnyObject {
    var currentCloudSchemaVersion: Int { get }
    func verifyEncryption(_ cloudData: VaultCloudData) -> Bool
    func passwordDataToPasswordEncryptedData(_ passwordData: PasswordData) -> ItemEncryptedData?
    func passwordEncyptedToPasswordData(_ passwordEncrypted: ItemEncryptedData) -> PasswordData?
    func tagToTagEncrypted(_ tag: ItemTagData) -> ItemTagEncryptedData?
    func tagEncyptedToTag(_ tagEncrypted: ItemTagEncryptedData) -> ItemTagData?
    func vaultEncryptedDataToVaultRawData(_ vault: VaultEncryptedData) -> VaultRawData?
    func updateCloudVault(_ cloudVault: VaultCloudData) -> VaultCloudData?
}
