// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import CloudKit
import Common

final class VaultRecord {
    enum VaultEntryKey: String {
        case vaultID
        case name
        case createdAt
        case updatedAt
        case deviceNames
        case deviceID
        case schemaVersion
        case seedHash
        case reference
        case kdfSpec
    }
    
    private(set) var vaultID: VaultID
    private(set) var name: String
    private(set) var createdAt: Date
    private(set) var updatedAt: Date
    private(set) var deviceNames: Data // [DeviceName]
    private(set) var deviceID: DeviceID
    private(set) var schemaVersion: Int
    private(set) var seedHash: String
    private(set) var reference: String
    private(set) var kdfSpec: Data // KDFSpec
    
    private(set) var ckRecord: CKRecord?
    
    init(record: CKRecord) {
        vaultID = UUID(uuidString: record[.vaultID] as! String)!
        name = record[.name] as! String
        createdAt = record[.createdAt] as! Date
        updatedAt = record[.updatedAt] as! Date
        deviceNames = record[.deviceNames] as! Data
        deviceID = UUID(uuidString: record[.deviceID] as! String)!
        schemaVersion = record[.schemaVersion] as! Int
        seedHash = record[.seedHash] as! String
        reference = record[.reference] as! String
        kdfSpec = record[.kdfSpec] as! Data
        
        ckRecord = record
    }
    
    func updateCreationDate(_ date: Date) {
        createdAt = date
    }
    
    func updateModificationDate(_ date: Date) {
        updatedAt = date
    }
    
    func encodeSystemFields() -> Data {
        guard let ckRecord else { fatalError("No record saved!") }
        return ckRecord.encodeSystemFields()
    }
    
    static func recreate(
        with metadata: Data,
        vaultID: VaultID,
        name: String,
        createdAt: Date,
        updatedAt: Date,
        deviceNames: Data,
        deviceID: DeviceID,
        schemaVersion: Int,
        seedHash: String,
        reference: String,
        kdfSpec: Data
    ) -> CKRecord? {
        guard let decoder = try? NSKeyedUnarchiver(forReadingFrom: metadata) else { return nil }
        decoder.requiresSecureCoding = true
        guard let record = CKRecord(coder: decoder) else { return nil }
        decoder.finishDecoding()
        
        update(
            record,
            vaultID: vaultID,
            name: name,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deviceNames: deviceNames,
            deviceID: deviceID,
            schemaVersion: schemaVersion,
            seedHash: seedHash,
            reference: reference,
            kdfSpec: kdfSpec
        )
        
        return record
    }
    
    static func createRecordName(for vaultID: VaultID) -> String {
        "\(RecordType.vault.rawValue)_\(vaultID.uuidString)"
    }
    
    static func create(
        zoneID: CKRecordZone.ID,
        vaultID: VaultID,
        name: String,
        createdAt: Date,
        updatedAt: Date,
        deviceNames: Data,
        deviceID: DeviceID,
        schemaVersion: Int,
        seedHash: String,
        reference: String,
        kdfSpec: Data
    ) -> CKRecord? {
        let record = CKRecord(
            recordType: RecordType.vault.rawValue,
            recordID: CKRecord.ID(recordName: createRecordName(for: vaultID), zoneID: zoneID)
        )
        
        update(
            record,
            vaultID: vaultID,
            name: name,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deviceNames: deviceNames,
            deviceID: deviceID,
            schemaVersion: schemaVersion,
            seedHash: seedHash,
            reference: reference,
            kdfSpec: kdfSpec
        )
        
        return record
    }
    
    static func update(
        _ record: CKRecord,
        vaultID: VaultID,
        name: String,
        createdAt: Date,
        updatedAt: Date,
        deviceNames: Data,
        deviceID: DeviceID,
        schemaVersion: Int,
        seedHash: String,
        reference: String,
        kdfSpec: Data
    ) {
        record[.vaultID] = vaultID.uuidString as CKRecordValue
        record[.name] = name as CKRecordValue
        record[.createdAt] = createdAt as CKRecordValue
        record[.updatedAt] = updatedAt as CKRecordValue
        record[.deviceNames] = deviceNames as CKRecordValue
        record[.deviceID] = deviceID.uuidString as CKRecordValue
        record[.schemaVersion] = schemaVersion as CKRecordValue
        record[.seedHash] = seedHash as CKRecordValue
        record[.reference] = reference as CKRecordValue
        record[.kdfSpec] = kdfSpec as CKRecordValue
    }
}

private extension CKRecord {
    subscript(_ key: VaultRecord.VaultEntryKey) -> CKRecordValue? {
        get { self[key.rawValue] }
        set { self[key.rawValue] = newValue }
    }
}
