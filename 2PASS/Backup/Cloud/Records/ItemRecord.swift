// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import CloudKit
import Common

final class ItemRecord {
    enum ItemEntryKey: String {
        case itemID
        case contentType
        case contentVersion
        case creationDateKey
        case modificationDateKey
        case protectionLevel
        case tagIds
        case vaultID
    }
    
    enum ItemEncryptedEntryKey: String {
        case content
    }
    
    private(set) var itemID: ItemID
    private(set) var content: Data
    private(set) var contentType: String
    private(set) var contentVersion: Int
    private(set) var creationDate: Date
    private(set) var modificationDate: Date
    private(set) var protectionLevel: Data // PasswordProtectionLevel
    private(set) var tagIds: Data?
    private(set) var vaultID: VaultID
    
    private(set) var ckRecord: CKRecord?
    
    init(record: CKRecord) {
        itemID = UUID(uuidString: record[.itemID] as! String)!
        content = record[.content] as! Data
        contentType = record[.contentType] as! String
        contentVersion = record[.contentVersion] as! Int
        creationDate = record[.creationDateKey] as! Date
        modificationDate = record[.modificationDateKey] as! Date
        protectionLevel = record[.protectionLevel] as! Data
        tagIds = record[.tagIds] as? Data
        vaultID = UUID(uuidString: record[.vaultID] as! String)!
        ckRecord = record
    }
    
    func encodeSystemFields() -> Data {
        guard let ckRecord else { fatalError("No record saved!") }
        return ckRecord.encodeSystemFields()
    }
    
    static func recreate(
        with metadata: Data,
        itemID: ItemID,
        content: Data,
        contentType: String,
        contentVersion: Int,
        creationDate: Date,
        modificationDate: Date,
        protectionLevel: Data,
        tagIds: Data?,
        vaultID: VaultID
    ) -> CKRecord? {
        guard let decoder = try? NSKeyedUnarchiver(forReadingFrom: metadata) else { return nil }
        decoder.requiresSecureCoding = true
        guard let record = CKRecord(coder: decoder) else { return nil }
        decoder.finishDecoding()
        
        update(
            record,
            itemID: itemID,
            content: content,
            contentType: contentType,
            contentVersion: contentVersion,
            creationDate: creationDate,
            modificationDate: modificationDate,
            protectionLevel: protectionLevel,
            tagIds: tagIds,
            vaultID: vaultID
        )
        return record
    }
    
    static func createRecordName(for itemID: ItemID) -> String {
        "\(RecordType.item.rawValue)_\(itemID.uuidString)"
    }
    
    static func create(
        zoneID: CKRecordZone.ID,
        itemID: ItemID,
        content: Data,
        contentType: String,
        contentVersion: Int,
        creationDate: Date,
        modificationDate: Date,
        protectionLevel: Data,
        tagIds: Data?,
        vaultID: VaultID
    ) -> CKRecord? {
        let record = CKRecord(
            recordType: RecordType.item.rawValue,
            recordID: CKRecord.ID(recordName: createRecordName(for: itemID), zoneID: zoneID)
        )
        
        update(
            record,
            itemID: itemID,
            content: content,
            contentType: contentType,
            contentVersion: contentVersion,
            creationDate: creationDate,
            modificationDate: modificationDate,
            protectionLevel: protectionLevel,
            tagIds: tagIds,
            vaultID: vaultID
        )
        return record
    }
    
    static func update(
        _ record: CKRecord,
        itemID: ItemID,
        content: Data,
        contentType: String,
        contentVersion: Int,
        creationDate: Date,
        modificationDate: Date,
        protectionLevel: Data,
        tagIds: Data?,
        vaultID: VaultID
    ) {
        record[.itemID] = itemID.uuidString as CKRecordValue
        record[.content] = content as CKRecordValue
        record[.contentType] = contentType as CKRecordValue
        record[.contentVersion] = contentVersion as CKRecordValue
        record[.creationDateKey] = creationDate as CKRecordValue
        record[.modificationDateKey] = modificationDate as CKRecordValue
        record[.protectionLevel] = protectionLevel as CKRecordValue
        if let tagIds {
            record[.tagIds] = tagIds as CKRecordValue
        } else {
            record[.tagIds] = nil
        }
        record[.vaultID] = vaultID.uuidString as CKRecordValue
    }
}

private extension CKRecord {
    subscript(_ key: ItemRecord.ItemEntryKey) -> CKRecordValue? {
        get { self[key.rawValue] }
        set { self[key.rawValue] = newValue }
    }
    
    subscript(_ key: ItemRecord.ItemEncryptedEntryKey) -> CKRecordValue? {
        get { self.encryptedValues[key.rawValue] }
        set { self.encryptedValues[key.rawValue] = newValue }
    }
}
