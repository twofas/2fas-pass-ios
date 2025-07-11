// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common
import CloudKit

// FIXME: Migrate to Items

extension PasswordRecord {
    static func recreate(
        jsonEncoder: JSONEncoder,
        metadata: Data,
        data: ItemEncryptedData
    ) -> CKRecord? {
        fatalError("Not yet implemented")
        
//        guard let iconType = try? jsonEncoder.encode(data.iconType),
//              let protectionLevel = try? jsonEncoder.encode(data.protectionLevel),
//              let uris = try? jsonEncoder.encode(data.uris) else {
//            return nil
//        }
//        return recreate(
//            with: metadata,
//            passwordID: data.passwordID,
//            name: data.name,
//            username: data.username,
//            password: data.password,
//            notes: data.notes,
//            creationDate: data.creationDate,
//            modificationDate: data.modificationDate,
//            iconType: iconType,
//            protectionLevel: protectionLevel,
//            vaultID: data.vaultID,
//            uris: uris
//        )
    }
    
    static func create(passwordEncryptedData: ItemEncryptedData, jsonEncoder: JSONEncoder) -> CKRecord? {
        fatalError("Not yet implemented")
        
//        guard let iconType = try? jsonEncoder.encode(passwordEncryptedData.iconType),
//              let protectionLevel = try? jsonEncoder.encode(passwordEncryptedData.protectionLevel),
//              let uris = try? jsonEncoder.encode(passwordEncryptedData.uris) else {
//            return nil
//        }
//        
//        return create(
//            zoneID: .from(vaultID: passwordEncryptedData.vaultID),
//            passwordID: passwordEncryptedData.passwordID,
//            name: passwordEncryptedData.name,
//            username: passwordEncryptedData.username,
//            password: passwordEncryptedData.password,
//            notes: passwordEncryptedData.notes,
//            creationDate: passwordEncryptedData.creationDate,
//            modificationDate: passwordEncryptedData.modificationDate,
//            iconType: iconType,
//            protectionLevel: protectionLevel,
//            vaultID: passwordEncryptedData.vaultID,
//            uris: uris
//        )
    }
    
    func toRecordData(jsonDecoder: JSONDecoder) -> RecordDataPassword? {
        fatalError("Not yet implemented")
        
//        guard let iconTypeParsed = try? jsonDecoder.decode(PasswordEncryptedIconType.self, from: iconType),
//              let protectionLevelParsed = try? jsonDecoder.decode(PasswordProtectionLevel.self, from: protectionLevel)
//        else {
//            return nil
//        }
//        let urisParsed: PasswordEncryptedURIs?
//        if let uris {
//            urisParsed = try? jsonDecoder.decode(PasswordEncryptedURIs.self, from: uris)
//        } else {
//            urisParsed = nil
//        }
//        
//        return .init(
//            password: .init(
//                passwordID: passwordID,
//                name: name,
//                username: username,
//                password: password,
//                notes: notes,
//                creationDate: creationDate,
//                modificationDate: modificationDate,
//                iconType: iconTypeParsed,
//                trashedStatus: .no,
//                protectionLevel: protectionLevelParsed,
//                vaultID: vaultID,
//                uris: urisParsed,
//                tagIds: nil
//            ),
//            metadata: encodeSystemFields()
//        )
    }
}
