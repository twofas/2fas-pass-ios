// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import CloudKit
import Common

final class DeletedItemRecord {
    enum DeletedItemEntryKey: String {
        case itemID
        case kind
        case vaultID
        case deletedAt
    }
    
    private(set) var itemID: DeletedItemID
    private(set) var kind: DeletedItemData.Kind
    private(set) var vaultID: VaultID
    private(set) var deletedAt: Date
    
    private(set) var ckRecord: CKRecord?
    
    init(record: CKRecord) {
        itemID = UUID(uuidString: record[.itemID] as! String)!
        kind = .init(rawValue: record[.kind] as! String)!
        vaultID = UUID(uuidString: record[.vaultID] as! String)!
        deletedAt = record[.deletedAt] as! Date
        
        ckRecord = record
    }
    
    func encodeSystemFields() -> Data {
        guard let ckRecord else { fatalError("No record saved!") }
        return ckRecord.encodeSystemFields()
    }
    
    static func recreate(
        with metadata: Data,
        itemID: DeletedItemID,
        kind: DeletedItemData.Kind,
        vaultID: VaultID,
        deletedAt: Date
    ) -> CKRecord? {
        guard let decoder = try? NSKeyedUnarchiver(forReadingFrom: metadata) else { return nil }
        decoder.requiresSecureCoding = true
        guard let record = CKRecord(coder: decoder) else { return nil }
        decoder.finishDecoding()
        
        update(
            record,
            itemID: itemID,
            kind: kind,
            vaultID: vaultID,
            deletedAt: deletedAt
        )
        
        return record
    }
    
    static func createRecordName(for itemID: DeletedItemID) -> String {
        "\(RecordType.deletedItem.rawValue)_\(itemID.uuidString)"
    }
    
    static func create(
        zoneID: CKRecordZone.ID,
        itemID: DeletedItemID,
        kind: DeletedItemData.Kind,
        vaultID: VaultID,
        deletedAt: Date
    ) -> CKRecord? {
        let record = CKRecord(
            recordType: RecordType.deletedItem.rawValue,
            recordID: CKRecord.ID(recordName: createRecordName(for: itemID), zoneID: zoneID)
        )
        
        update(
            record,
            itemID: itemID,
            kind: kind,
            vaultID: vaultID,
            deletedAt: deletedAt
        )
        
        return record
    }
    
    static func update(
        _ record: CKRecord,
        itemID: DeletedItemID,
        kind: DeletedItemData.Kind,
        vaultID: VaultID,
        deletedAt: Date
    ) {
        record[.itemID] = itemID.uuidString as CKRecordValue
        record[.kind] = kind.rawValue as CKRecordValue
        record[.vaultID] = vaultID.uuidString as CKRecordValue
        record[.deletedAt] = deletedAt as CKRecordValue
    }
}

private extension CKRecord {
    subscript(_ key: DeletedItemRecord.DeletedItemEntryKey) -> CKRecordValue? {
        get { self[key.rawValue] }
        set { self[key.rawValue] = newValue }
    }
}
