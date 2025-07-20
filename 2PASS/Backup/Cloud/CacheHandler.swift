// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import CloudKit
import Common

final class CacheHandler {
    private let cloudCacheStorage: CloudCacheStorage
    private let jsonDecoder: JSONDecoder
    
    init(cloudCacheStorage: CloudCacheStorage, jsonDecoder: JSONDecoder) {
        self.cloudCacheStorage = cloudCacheStorage
        self.jsonDecoder = jsonDecoder
    }
}

extension CacheHandler {
    func purge() {
        Log("CacheHandler - Purging all data", module: .cloudSync)
        LogZoneStart()
        cloudCacheStorage.purge()
        LogZoneEnd()
        cloudCacheStorage.save()
    }
    
    func deleteEntries(_ entries: [EntityOfKind]) {
        entries.forEach { entryID, type in
            let entries = entryID.split(separator: "_")
            if entries.count == 2, let entryIDParsed = entries[safe: 1], let recordID = UUID(uuidString: String(entryIDParsed)) {
                switch type {
                case .password: break // deprecated - no action taken
                case .item: cloudCacheStorage.deleteItem(itemID: recordID)
                case .deletedItem: cloudCacheStorage.deleteDeletedItem(deletedItemID: recordID)
                case .tag: cloudCacheStorage.deleteTag(tagID: recordID)
                case .vault: cloudCacheStorage.deleteVault(vaultID: recordID)
                }
            }
        }
    }
    
    func updateOrCreate(with entries: [CKRecord]) {
        let items = cloudCacheStorage.listItemIDsModificationDate()
        let deletedItems = cloudCacheStorage.listDeletedItemsIDsDeletitionDate()
        let tags = cloudCacheStorage.listTagsItemsIDsModificationDate()
        let vaults = cloudCacheStorage.listAllVaultIDs()
        entries.forEach { record in
            if let recordType = RecordType(rawValue: record.recordType) {
                switch recordType {
                case .password: break // deprecated - no action taken
                case .item:
                    let itemRecord = ItemRecord(record: record)
                    let id = itemRecord.itemID
                        if let item = items.first(where: { $0.0 == id }) {
                            if item.1 != itemRecord.modificationDate, let item = itemRecord.toRecordData(jsonDecoder: jsonDecoder) {
                                cloudCacheStorage.updateItem(item: item.item, metadata: item.metadata)
                            }
                        } else {
                            if let item = itemRecord.toRecordData(jsonDecoder: jsonDecoder) {
                                cloudCacheStorage.createItem(item: item.item, metadata: item.metadata)
                            }
                        }
                case .deletedItem:
                    let deletedItemRecord = DeletedItemRecord(record: record)
                    let id = deletedItemRecord.itemID
                    if let deleted = deletedItems.first(where: { $0.0 == id }) {
                        if deleted.1 != deletedItemRecord.deletedAt {
                            let deletedItem = deletedItemRecord.toRecordData()
                            cloudCacheStorage
                                .updateDeletedItem(
                                    .init(
                                        deletedItem: DeletedItemData(
                                            itemID: deletedItem.deletedItem.itemID,
                                            vaultID: deletedItem.deletedItem.vaultID,
                                            kind: deletedItem.deletedItem.kind,
                                            deletedAt: deletedItem.deletedItem.deletedAt
                                        ),
                                        metadata: deletedItem.metadata
                                    )
                                )
                        }
                    } else {
                        let deletedItem = deletedItemRecord.toRecordData()
                        cloudCacheStorage.createDeletedItem(
                            .init(
                                deletedItem: .init(
                                    itemID: deletedItem.deletedItem.itemID,
                                    vaultID: deletedItem.deletedItem.vaultID,
                                    kind: deletedItem.deletedItem.kind,
                                    deletedAt: deletedItem.deletedItem.deletedAt
                                ),
                                metadata: deletedItem.metadata
                            )
                        )
                    }
                case .tag:
                    let tagRecord = TagRecord(record: record)
                    let tagID = tagRecord.tagID
                    if let tag = tags.first(where: { $0.0 == tagID }) {
                        if tag.1 != tagRecord.modificationDate {
                            let tagItem = tagRecord.toRecordData()
                            cloudCacheStorage
                                .updateTagItem(
                                    .init(
                                        tagItem: .init(
                                            tagID: tagItem.tagItem.tagID,
                                            vaultID: tagItem.tagItem.vaultID,
                                            name: tagItem.tagItem.name,
                                            color: tagItem.tagItem.color,
                                            position: tagItem.tagItem.position,
                                            modificationDate: tagItem.tagItem.modificationDate
                                        ),
                                        metadata: tagItem.metadata
                                    )
                                )
                        }
                    } else {
                        let tagItem = tagRecord.toRecordData()
                        cloudCacheStorage.createTagItem(
                            .init(
                                tagItem: .init(
                                    tagID: tagItem.tagItem.tagID,
                                    vaultID: tagItem.tagItem.vaultID,
                                    name: tagItem.tagItem.name,
                                    color: tagItem.tagItem.color,
                                    position: tagItem.tagItem.position,
                                    modificationDate: tagItem.tagItem.modificationDate
                                ),
                                metadata: tagItem.metadata
                            )
                        )
                    }
                case .vault:
                    let vaultRecord = VaultRecord(record: record)
                    let id = vaultRecord.vaultID
                    let vault = vaultRecord.toRecordData()
                    if vaults.contains(where: { $0 == id }) {
                        cloudCacheStorage.updateVault(vault: vault)
                    } else {
                        cloudCacheStorage.createVault(vault: vault)
                    }
                }
            }
        }
    }
    
    func commitChanges() {
        cloudCacheStorage.save()
    }
    
    func listAllItemsRecordIDs() -> [CKRecord.ID] {
        let itemIDList: [ItemID] = cloudCacheStorage.listAllItemsInCurrentVault().map({ $0.item.itemID })
        let deletedItemIDList: [DeletedItemID] = cloudCacheStorage.listAllDeletedItemsInCurrentVault().map({ $0.deletedItem.itemID })
        let tagItemIDList: [ItemTagID] = cloudCacheStorage.listAllTagsInCurrentVault().map({ $0.tagItem.tagID })
        
        var vaultIDList: [UUID] = []
        
        guard let vaultID = cloudCacheStorage.currentVault?.id else { return [] }

        vaultIDList.append(vaultID)
        let zoneID: CKRecordZone.ID = .from(vaultID: vaultID)

        var allRecords: [CKRecord.ID] = itemIDList.map({ CKRecord.ID(recordName: ItemRecord.createRecordName(for: $0), zoneID: zoneID) })
        allRecords += deletedItemIDList.map({ CKRecord.ID(recordName: DeletedItemRecord.createRecordName(for: $0), zoneID: zoneID) })
        allRecords += tagItemIDList
            .map({ CKRecord.ID(recordName: TagRecord.createRecordName(for: $0), zoneID: zoneID)})
        allRecords += vaultIDList.map({ CKRecord.ID(recordName: VaultRecord.createRecordName(for: $0), zoneID: zoneID) })
        return allRecords
    }
}
