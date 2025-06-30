// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import CloudKit
import Common

final class PasswordRecord {
    enum PasswordEntryKey: String {
        case passwordID
        case creationDateKey
        case modificationDateKey
        case protectionLevel
        case vaultID
    }
    
    enum PasswordEncryptedEntryKey: String {
        case name
        case username
        case password
        case notes
        case iconType
        case uris
    }
    
    private(set) var passwordID: PasswordID
    private(set) var name: Data?
    private(set) var username: Data?
    private(set) var password: Data?
    private(set) var notes: Data?
    private(set) var creationDate: Date
    private(set) var modificationDate: Date
    private(set) var iconType: Data // PasswordEncryptedIconType
    private(set) var protectionLevel: Data // PasswordProtectionLevel
    private(set) var vaultID: VaultID
    private(set) var uris: Data? // PasswordEncryptedURIs
    
    private(set) var ckRecord: CKRecord?
    
    init(record: CKRecord) {
        passwordID = UUID(uuidString: record[.passwordID] as! String)!
        name = record[.name] as? Data
        username = record[.username] as? Data
        password = record[.password] as? Data
        notes = record[.notes] as? Data
        creationDate = record[.creationDateKey] as! Date
        modificationDate = record[.modificationDateKey] as! Date
        iconType = record[.iconType] as! Data
        protectionLevel = record[.protectionLevel] as! Data
        vaultID = UUID(uuidString: record[.vaultID] as! String)!
        uris = record[.uris] as? Data
        
        ckRecord = record
    }
    
    func encodeSystemFields() -> Data {
        guard let ckRecord else { fatalError("No record saved!") }
        return ckRecord.encodeSystemFields()
    }
    
    static func recreate(
        with metadata: Data,
        passwordID: PasswordID,
        name: Data?,
        username: Data?,
        password: Data?,
        notes: Data?,
        creationDate: Date,
        modificationDate: Date,
        iconType: Data,
        protectionLevel: Data,
        vaultID: VaultID,
        uris: Data?
    ) -> CKRecord? {
        guard let decoder = try? NSKeyedUnarchiver(forReadingFrom: metadata) else { return nil }
        decoder.requiresSecureCoding = true
        guard let record = CKRecord(coder: decoder) else { return nil }
        decoder.finishDecoding()
        
        update(
            record,
            passwordID: passwordID,
            name: name,
            username: username,
            password: password,
            notes: notes,
            creationDate: creationDate,
            modificationDate: modificationDate,
            iconType: iconType,
            protectionLevel: protectionLevel,
            vaultID: vaultID,
            uris: uris
        )
        return record
    }
    
    static func createRecordName(for passwordID: PasswordID) -> String {
        "\(RecordType.password.rawValue)_\(passwordID.uuidString)"
    }
    
    static func create(
        zoneID: CKRecordZone.ID,
        passwordID: PasswordID,
        name: Data?,
        username: Data?,
        password: Data?,
        notes: Data?,
        creationDate: Date,
        modificationDate: Date,
        iconType: Data,
        protectionLevel: Data,
        vaultID: VaultID,
        uris: Data?
    ) -> CKRecord? {
        let record = CKRecord(
            recordType: RecordType.password.rawValue,
            recordID: CKRecord.ID(recordName: createRecordName(for: passwordID), zoneID: zoneID)
        )
        
        update(
            record,
            passwordID: passwordID,
            name: name,
            username: username,
            password: password,
            notes: notes,
            creationDate: creationDate,
            modificationDate: modificationDate,
            iconType: iconType,
            protectionLevel: protectionLevel,
            vaultID: vaultID,
            uris: uris
        )
        return record
    }
    
    static func update(
        _ record: CKRecord,
        passwordID: PasswordID,
        name: Data?,
        username: Data?,
        password: Data?,
        notes: Data?,
        creationDate: Date,
        modificationDate: Date,
        iconType: Data,
        protectionLevel: Data,
        vaultID: VaultID,
        uris: Data?
    ) {
        record[.passwordID] = passwordID.uuidString as CKRecordValue
        if let name {
            record[.name] = name as CKRecordValue
        } else {
            record[.name] = nil
        }
        
        if let username {
            record[.username] = username as CKRecordValue
        } else {
            record[.username] = nil
        }
        
        if let password {
            record[.password] = password as CKRecordValue
        } else {
            record[.password] = nil
        }
        
        if let notes {
            record[.notes] = notes as CKRecordValue
        } else {
            record[.notes] = nil
        }
        
        record[.creationDateKey] = creationDate as CKRecordValue
        record[.modificationDateKey] = modificationDate as CKRecordValue
        record[.iconType] = iconType as CKRecordValue
        record[.protectionLevel] = protectionLevel as CKRecordValue
        record[.vaultID] = vaultID.uuidString as CKRecordValue
        
        if let uris {
            record[.uris] = uris as CKRecordValue
        } else {
            record[.uris] =  nil
        }
    }
}

private extension CKRecord {
    subscript(_ key: PasswordRecord.PasswordEntryKey) -> CKRecordValue? {
        get { self[key.rawValue] }
        set { self[key.rawValue] = newValue }
    }
    
    subscript(_ key: PasswordRecord.PasswordEncryptedEntryKey) -> CKRecordValue? {
        get { self.encryptedValues[key.rawValue] }
        set { self.encryptedValues[key.rawValue] = newValue }
    }
}
