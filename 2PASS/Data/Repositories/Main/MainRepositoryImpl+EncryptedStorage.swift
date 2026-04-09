// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import CryptoKit
import Common
import Storage

extension MainRepositoryImpl {
    
    // MARK: Items
    
    func createEncryptedItem(
        itemID: ItemID,
        creationDate: Date,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        contentType: ItemContentType,
        contentVersion: Int,
        content: Data,
        vaultID: VaultID,
        tagIds: [ItemTagID]?
    ) {
        encryptedStorage.createEncryptedItem(
            itemID: itemID,
            creationDate: creationDate,
            modificationDate: modificationDate,
            trashedStatus: trashedStatus,
            protectionLevel: protectionLevel,
            contentType: contentType,
            contentVersion: contentVersion,
            content: content,
            vaultID: vaultID,
            tagIds: tagIds
        )
    }
    
    func updateEncryptedItem(
        itemID: ItemID,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        contentType: ItemContentType,
        contentVersion: Int,
        content: Data,
        vaultID: VaultID,
        tagIds: [ItemTagID]?
    ) {
        encryptedStorage.updateEncryptedItem(
            itemID: itemID,
            modificationDate: modificationDate,
            trashedStatus: trashedStatus,
            protectionLevel: protectionLevel,
            contentType: contentType,
            contentVersion: contentVersion,
            content: content,
            vaultID: vaultID,
            tagIds: tagIds
        )
    }
    
    func encryptedItemsBatchUpdate(_ items: [ItemEncryptedData]) {
        encryptedStorage.batchUpdateRencryptedItems(items, date: currentDate)
    }
    
    func getEncryptedItemEntity(itemID: ItemID) -> ItemEncryptedData? {
        encryptedStorage.getEncryptedItemEntity(itemID: itemID)
    }
    
    func listAllEncryptedItems() -> [ItemEncryptedData] {
        encryptedStorage.listAllEncryptedItems()
    }

    func listEncryptedItems(in vaultID: VaultID) -> [ItemEncryptedData] {
        encryptedStorage.listEncryptedItems(in: vaultID)
    }
    
    func listEncryptedItems(
        in vaultID: VaultID,
        itemIDs: [ItemID]?,
        excludeProtectionLevels: Set<ItemProtectionLevel>?
    ) -> [ItemEncryptedData] {
        encryptedStorage.listEncryptedItems(
            in: vaultID,
            itemIDs: itemIDs,
            excludeProtectionLevels: excludeProtectionLevels
        )
    }

    func listEncryptedItems(
        itemIDs: [ItemID],
        excludeProtectionLevels: Set<ItemProtectionLevel>?
    ) -> [ItemEncryptedData] {
        encryptedStorage.listEncryptedItems(
            itemIDs: itemIDs,
            excludeProtectionLevels: excludeProtectionLevels
        )
    }
    
    func addEncryptedItem(_ itemID: ItemID, to vaultID: VaultID) {
        encryptedStorage.addEncryptedItem(itemID, to: vaultID)
    }
    
    func deleteEncryptedItem(itemID: ItemID) {
        encryptedStorage.deleteEncryptedItem(itemID: itemID)
    }
    
    func deleteAllEncryptedItems() {
        encryptedStorage.deleteAllEncryptedItems(in: nil)
    }
    
    // MARK: Encrypted Vaults
    
    func listEncryptedVaults() -> [VaultEncryptedData] {
        encryptedStorage.listEncrypteVaults()
    }
    
    func getEncryptedVault(for vaultID: VaultID) -> VaultEncryptedData? {
        encryptedStorage.getEncryptedVault(for: vaultID)
    }
    
    func createEncryptedVault(
        vaultID: VaultID,
        name: Data,
        trustedKey: Data,
        createdAt: Date,
        updatedAt: Date,
        color: String?,
        icon: String?
    ) {
        encryptedStorage.createEncryptedVault(
            vaultID: vaultID,
            name: name,
            trustedKey: trustedKey,
            createdAt: createdAt,
            updatedAt: updatedAt,
            color: color,
            icon: icon
        )
    }

    func updateEncryptedVault(
        vaultID: VaultID,
        name: Data,
        trustedKey: Data,
        createdAt: Date,
        updatedAt: Date,
        color: String? = nil,
        icon: String? = nil
    ) {
        encryptedStorage.updateEncryptedVault(
            vaultID: vaultID,
            name: name,
            trustedKey: trustedKey,
            createdAt: createdAt,
            updatedAt: updatedAt,
            color: color,
            icon: icon
        )
    }

    func deleteAllVaults() {
        listEncryptedVaults().forEach { vault in
            deleteEncryptedVault(vault.vaultID)
        }
        saveEncryptedStorage()
    }
    
    func deleteEncryptedVault(_ vaultID: VaultID) {
        encryptedStorage.deleteEncryptedVault(vaultID)
    }
    
    func saveEncryptedStorage() {
        Log("Save Encrypted Storage", module: .mainRepository)
        encryptedStorage.save()
    }
    
    func requiresReencryptionMigration() -> Bool {
        hasEncryptionReference && encryptedStorage.requiresReencryptionMigration
    }
    
    func loadEncryptedStore(completion: @escaping Callback) {
        encryptedStorage.loadStore { [weak encryptedStorage] success in
            guard success else { fatalError("Failed to load Encrypted store") }
            encryptedStorage?.warmUp()
            completion()
        }
    }
    
    func loadEncryptedStoreWithReencryptionMigration(completion: @escaping (Bool) -> Void) {
        // Materialize the metadata key up front so the WebBrowser V2→V3 policy can
        // re-encrypt rows during migration. The metadata key is deterministically
        // derived from the master key via HMAC, matching the runtime derivation
        // performed at unlock.
        if let masterKey = empheralMasterKey,
           let metadataKeyHex = generateMetadataKey(using: masterKey.hexEncodedString()),
           let metadataKeyData = Data(hexString: metadataKeyHex) {
            setMetadataKey(metadataKeyData)
            prepareMetadataKeyCache()
        } else {
            Log("Error while preparing Metadata Key for migration", severity: .error)
        }

        // Lazily derive and cache per-vault trusted/secure/external keys on first
        // use. Idempotent via `hasCachedKeys(for:)` so repeated calls for the same
        // vault are effectively free.
        let ensureVaultKeys: (VaultID) -> Void = { vaultID in
            guard self.hasCachedKeys(for: vaultID) == false else {
                return
            }

            guard let masterKey = self.empheralMasterKey else {
                Log("Error while getting Master Key - it's missing", severity: .error)
                return
            }

            guard let trustedKey = self.generateTrustedKeyForVaultID(vaultID, using: masterKey.hexEncodedString()),
                let trustedKeyData = Data(hexString: trustedKey) else {
                return
            }
            self.setTrustedKey(trustedKeyData, forVault: vaultID)

            guard let secureKey = self.generateSecureKeyForVaultID(vaultID, using: masterKey.hexEncodedString()),
                let secureKeyData = Data(hexString: secureKey) else {
                return
            }
            self.setSecureKey(secureKeyData, forVault: vaultID)

            guard let externalKey = self.generateExternalKeyForVaultID(vaultID, using: masterKey.hexEncodedString()),
                let externalKeyData = Data(hexString: externalKey) else {
                return
            }
            self.setExternalKey(externalKeyData, forVault: vaultID)

            self.preparedCachedKeys(for: vaultID)
        }

        // Resolve the AppKey-derived Secure Enclave symmetric key once. This is the
        // pre-feature/new-keys WebBrowsersInteractor key path; the WebBrowser V2→V3
        // policy invokes it 5× per row, and `createSymmetricKeyFromSecureEnclave`
        // hits the Secure Enclave on every call (no internal memoization).
        let appKeySymmetric: SymmetricKey? = self.appKey.flatMap(self.createSymmetricKeyFromSecureEnclave(from:))

        let resolveKey: (EncryptionKey) -> SymmetricKey? = { encryptionKey in
            switch encryptionKey {
            case let .vault(vaultID, protectionLevel):
                ensureVaultKeys(vaultID)
                return self.getKey(isPassword: false, protectionLevel: protectionLevel, forVault: vaultID)
            case .appKey:
                if appKeySymmetric == nil {
                    Log("Migration - can't resolve AppKey", severity: .error)
                }
                return appKeySymmetric
            case .metadataKey:
                guard let key = self.cachedMetadataKey() else {
                    Log("Migration - can't get cached metadata key", severity: .error)
                    return nil
                }
                return key
            }
        }

        MigrationController.current = .init(
            encrypt: { data, encryptionKey in
                guard let key = resolveKey(encryptionKey) else { return nil }
                return self.encrypt(data, key: key)
            },
            decrypt: { data, encryptionKey in
                guard let key = resolveKey(encryptionKey) else { return nil }
                return self.decrypt(data, key: key)
            }
        )

        encryptedStorage.loadStore { success in
            MigrationController.current = nil
            completion(success)
        }
    }
    
    // MARK: Deleted Items
    
    func createDeletedItem(id: DeletedItemID, kind: DeletedItemData.Kind, deletedAt: Date, in vaultID: VaultID) {
        Log("Creating Deleted Item for ItemID: \(id)", module: .mainRepository)
        encryptedStorage.createDeletedItem(id: id, kind: kind, deletedAt: deletedAt, in: vaultID)
    }
    
    func updateDeletedItem(id: DeletedItemID, kind: DeletedItemData.Kind, deletedAt: Date, in vaultID: VaultID) {
        Log("Updating Deleted Item for ItemID: \(id)", module: .mainRepository)
        encryptedStorage.updateDeletedItem(id: id, kind: kind, deletedAt: deletedAt, in: vaultID)
    }

    func updateDeletedItems(_ items: [DeletedItemData]) {
        Log("Bulk updating \(items.count) Deleted Items", module: .mainRepository)
        encryptedStorage.updateDeletedItems(items)
    }

    func deletedItem(id: DeletedItemID) -> DeletedItemData? {
        encryptedStorage.deletedItem(id: id)
    }

    func listDeletedItems(ids: Set<DeletedItemID>) -> [DeletedItemData] {
        encryptedStorage.listDeletedItems(ids: ids)
    }

    func listDeletedItems(in vaultID: VaultID, limit: Int?) -> [DeletedItemData] {
        encryptedStorage.listDeletedItems(in: vaultID, limit: limit)
    }
    
    func deleteDeletedItem(id: DeletedItemID) {
        Log("Deleting Deleted Item for ItemID: \(id)", module: .mainRepository)
        encryptedStorage.deleteDeletedItem(id: id)
    }

    func removeDuplicatedDeletedItems() {
        Log("Removing duplicated deleted items", module: .mainRepository)
        encryptedStorage.removeDuplicatedDeletedItems()
    }

    // MARK: Tags
    
    func createEncryptedTag(_ tag: ItemTagEncryptedData) {
        encryptedStorage.createEncryptedTag(tag)
    }
    
    func updateEncryptedTag(_ tag: ItemTagEncryptedData) {
        encryptedStorage.updateEncryptedTag(tag)
    }
    
    func deleteEncryptedTag(tagID: ItemTagID) {
        encryptedStorage.deleteEncryptedTag(tagID: tagID)
    }
    
    func listEncryptedTags(in vaultID: VaultID) -> [ItemTagEncryptedData] {
        encryptedStorage.listEncryptedTags(in: vaultID)
    }
    
    func encryptedTagBatchUpdate(_ tags: [ItemTagEncryptedData], in vault: VaultID) {
        encryptedStorage.encryptedTagBatchUpdate(tags, in: vault)
    }
    
    func deleteAllEncryptedTags(in vault: VaultID) {
        encryptedStorage.deleteAllEncryptedTags(in: vault)
    }

    func deleteAllEncryptedTags() {
        for vault in listEncryptedVaults() {
            encryptedStorage.deleteAllEncryptedTags(in: vault.vaultID)
        }
    }

    func listAllEncryptedTags() -> [ItemTagEncryptedData] {
        encryptedStorage.listAllEncryptedTags()
    }

    // MARK: Web Browser Extension
    
    func createEncryptedWebBrowser(_ data: WebBrowserEncryptedData) {
        encryptedStorage.createEncryptedWebBrowser(data)
    }
    
    func updateEncryptedWebBrowser(_ data: WebBrowserEncryptedData) {
        encryptedStorage.updateEncryptedWebBrowser(data)
    }
    
    func deleteEncryptedWebBrowser(id: UUID) {
        encryptedStorage.deleteEncryptedWebBrowser(id: id)
    }
    
    func listEncryptedWebBrowsers() -> [WebBrowserEncryptedData] {
        encryptedStorage.listEncryptedWebBrowsers()
    }
}
