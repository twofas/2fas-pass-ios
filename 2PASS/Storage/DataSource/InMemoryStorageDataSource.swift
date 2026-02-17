// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import CoreData
import Common

public protocol InMemoryStorageDataSource: AnyObject {
    var storageError: ((String) -> Void)? { get set }
    func loadStore(completion: @escaping LoadStoreCallback)
    
    // MARK: - Items
    
    func createItem(
        itemID: ItemID,
        vaultID: VaultID,
        creationDate: Date,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?,
        name: String?,
        contentType: ItemContentType,
        contentVersion: Int,
        content: Data
    )

    func updateMetadataItem(
        itemID: ItemID,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?,
        name: String?,
        contentType: ItemContentType,
        contentVersion: Int
    )
    
    func updateItem(
        itemID: ItemID,
        vaultID: VaultID,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?,
        name: String?,
        contentType: ItemContentType,
        contentVersion: Int,
        content: Data
    )
    
    func batchUpdateRencryptedItems(_ items: [RawItemData], date: Date)
    func batchUpdateMetadataItems(_ items: [any ItemDataType], date: Date)

    func getItemEntity(
        itemID: ItemID,
        checkInTrash: Bool
    ) -> ItemData?
    
    func listItems(
        options: ItemsListOptions
    ) -> [ItemData]
    
    func deleteItem(itemID: ItemID)
    func deleteAllItemEntities()
    
    // MARK: - Tags
    
    func createTag(
        tagID: ItemTagID,
        name: String,
        modificationDate: Date,
        position: Int16,
        vaultID: VaultID,
        color: ItemTagColor?
    )

    func updateTag(
        tagID: ItemTagID,
        name: String,
        modificationDate: Date,
        position: Int16,
        vaultID: VaultID,
        color: ItemTagColor?
    )
    
    func batchUpdateRencryptedTags(_ tags: [ItemTagData], date: Date)
    
    func getTagEntity(
        tagID: ItemTagID
    ) -> ItemTagData?
    
    func listTags(
        options: TagListOptions
    ) -> [ItemTagData]
    
    func deleteTag(tagID: ItemTagID)
    func deleteAllTagEntities()
    
    // MARK: - Login Items
    
    func createLoginItem(
        itemID: ItemID,
        vaultID: VaultID,
        creationDate: Date,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?,
        name: String?,
        username: String?,
        password: Data?,
        notes: String?,
        iconType: PasswordIconType,
        uris: [PasswordURI]?
    )
    
    func updateLoginItem(
        itemID: ItemID,
        vaultID: VaultID,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?,
        name: String?,
        username: String?,
        password: Data?,
        notes: String?,
        iconType: PasswordIconType,
        uris: [PasswordURI]?
    )
    
    func getLoginItem(
        itemID: ItemID,
        checkInTrash: Bool
    ) -> LoginItemData?
    
    func listLoginItems(
        options: ItemsListOptions
    ) -> [LoginItemData]
    
    // MARK: - Secure Note Items
    
    func createSecureNoteItem(
        itemID: ItemID,
        vaultID: VaultID,
        creationDate: Date,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?,
        name: String?,
        text: Data?,
        additionalInfo: String?
    )

    func updateSecureNoteItem(
        itemID: ItemID,
        vaultID: VaultID,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?,
        name: String?,
        text: Data?,
        additionalInfo: String?
    )
    
    func getSecureNoteItem(
        itemID: ItemID,
        checkInTrash: Bool
    ) -> SecureNoteItemData?
    
    func listSecureNoteItems(
        options: ItemsListOptions
    ) -> [SecureNoteItemData]

    // MARK: - Payment Card Items

    func createPaymentCardItem(
        itemID: ItemID,
        vaultID: VaultID,
        creationDate: Date,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?,
        name: String?,
        cardHolder: String?,
        cardNumber: Data?,
        expirationDate: Data?,
        securityCode: Data?,
        notes: String?,
        cardNumberMask: String?,
        cardIssuer: String?
    )

    func updatePaymentCardItem(
        itemID: ItemID,
        vaultID: VaultID,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?,
        name: String?,
        cardHolder: String?,
        cardNumber: Data?,
        expirationDate: Data?,
        securityCode: Data?,
        notes: String?,
        cardNumberMask: String?,
        cardIssuer: String?
    )

    func getPaymentCardItem(
        itemID: ItemID,
        checkInTrash: Bool
    ) -> PaymentCardItemData?

    func listPaymentCardItems(
        options: ItemsListOptions
    ) -> [PaymentCardItemData]

    // MARK: - WiFi Items

    func createWiFiItem(
        itemID: ItemID,
        vaultID: VaultID,
        creationDate: Date,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?,
        name: String?,
        ssid: String?,
        password: Data?,
        notes: String?,
        securityType: WiFiContent.SecurityType,
        hidden: Bool
    )

    func updateWiFiItem(
        itemID: ItemID,
        vaultID: VaultID,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?,
        name: String?,
        ssid: String?,
        password: Data?,
        notes: String?,
        securityType: WiFiContent.SecurityType,
        hidden: Bool
    )

    func getWiFiItem(
        itemID: ItemID,
        checkInTrash: Bool
    ) -> WiFiItemData?

    func listWiFiItems(
        options: ItemsListOptions
    ) -> [WiFiItemData]

    // MARK: - Other
    
    func listUsernames() -> [String]
    func warmUp()
    func save()
}
