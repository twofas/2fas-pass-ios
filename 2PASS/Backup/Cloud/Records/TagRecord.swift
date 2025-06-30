// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import CloudKit
import Common

final class TagRecord {
    enum TagEntryKey: String {
        case tagID
        case name
        case modificationDateKey
        case position
        case color
        case vaultID
    }

    private(set) var tagID: ItemTagID
    private(set) var name: Data
    private(set) var modificationDate: Date
    private(set) var position: Int
    private(set) var color: String?
    private(set) var vaultID: VaultID
    
    private(set) var ckRecord: CKRecord?
    
    init(record: CKRecord) {
        tagID = UUID(uuidString: record[.tagID] as! String)!
        name = record[.name] as! Data
        modificationDate = record[.modificationDateKey] as! Date
        position = record[.position] as! Int
        let colorValue = record[.color] as! String
        if colorValue.isEmpty {
            color = nil
        } else {
            color = colorValue
        }
        vaultID = UUID(uuidString: record[.vaultID] as! String)!
        
        ckRecord = record
    }
    
    func encodeSystemFields() -> Data {
        guard let ckRecord else { fatalError("No record saved!") }
        return ckRecord.encodeSystemFields()
    }
    
    static func recreate(
        with metadata: Data,
        tagID: ItemTagID,
        name: Data,
        modificationDate: Date,
        position: Int,
        color: String?,
        vaultID: VaultID
    ) -> CKRecord? {
        guard let decoder = try? NSKeyedUnarchiver(forReadingFrom: metadata) else { return nil }
        decoder.requiresSecureCoding = true
        guard let record = CKRecord(coder: decoder) else { return nil }
        decoder.finishDecoding()
        
        update(
            record,
            tagID: tagID,
            name: name,
            modificationDate: modificationDate,
            position: position,
            color: color,
            vaultID: vaultID
        )
        
        return record
    }
    
    static func createRecordName(for tagID: ItemTagID) -> String {
        "\(RecordType.tag.rawValue)_\(tagID.uuidString)"
    }
    
    static func create(
        zoneID: CKRecordZone.ID,
        tagID: ItemTagID,
        name: Data,
        modificationDate: Date,
        position: Int,
        color: String?,
        vaultID: VaultID
    ) -> CKRecord? {
        let record = CKRecord(
            recordType: RecordType.tag.rawValue,
            recordID: CKRecord.ID(recordName: createRecordName(for: tagID), zoneID: zoneID)
        )
        
        update(
            record,
            tagID: tagID,
            name: name,
            modificationDate: modificationDate,
            position: position,
            color: color,
            vaultID: vaultID
        )
        
        return record
    }
    
    static func update(
        _ record: CKRecord,
        tagID: ItemTagID,
        name: Data,
        modificationDate: Date,
        position: Int,
        color: String?,
        vaultID: VaultID
    ) {
        record[.tagID] = tagID.uuidString as CKRecordValue
        record[.name] = name as CKRecordValue
        record[.modificationDateKey] = modificationDate as CKRecordValue
        record[.position] = position as CKRecordValue
        record[.color] = (color ?? "") as CKRecordValue
        record[.vaultID] = vaultID.uuidString as CKRecordValue
    }
}

private extension CKRecord {
    subscript(_ key: TagRecord.TagEntryKey) -> CKRecordValue? {
        get { self[key.rawValue] }
        set { self[key.rawValue] = newValue }
    }
}
