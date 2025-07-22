// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common
import CloudKit

extension ItemRecord {
    static func recreate(
        jsonEncoder: JSONEncoder,
        metadata: Data,
        data: ItemEncryptedData
    ) -> CKRecord? {
        guard let protectionLevel = try? jsonEncoder.encode(data.protectionLevel) else {
            return nil
        }
        
        return recreate(
            with: metadata,
            itemID: data.itemID,
            content: data.content,
            contentType: data.contentType.rawValue,
            contentVersion: data.contentVersion,
            creationDate: data.creationDate,
            modificationDate: data.modificationDate,
            protectionLevel: protectionLevel,
            tagIds: data.tagIds?.toData(),
            vaultID: data.vaultID
        )

    }
    
    static func create(itemEncryptedData: ItemEncryptedData, jsonEncoder: JSONEncoder) -> CKRecord? {
        guard let protectionLevel = try? jsonEncoder.encode(itemEncryptedData.protectionLevel) else {
            return nil
        }
        
        return create(
            zoneID: .from(vaultID: itemEncryptedData.vaultID),
            itemID: itemEncryptedData.itemID,
            content: itemEncryptedData.content,
            contentType: itemEncryptedData.contentType.rawValue,
            contentVersion: itemEncryptedData.contentVersion,
            creationDate: itemEncryptedData.creationDate,
            modificationDate: itemEncryptedData.modificationDate,
            protectionLevel: protectionLevel,
            tagIds: itemEncryptedData.tagIds?.toData(),
            vaultID: itemEncryptedData.vaultID
        )
    }
    
    func toRecordData(jsonDecoder: JSONDecoder) -> RecordDataItem? {
        guard let protectionLevelParsed = try? jsonDecoder.decode(ItemProtectionLevel.self, from: protectionLevel) else {
            return nil
        }
        
        return .init(
            item: .init(
                itemID: itemID,
                creationDate: creationDate,
                modificationDate: modificationDate,
                trashedStatus: .no,
                protectionLevel: protectionLevelParsed,
                contentType: ItemContentType(rawValue: contentType) ?? .login,
                contentVersion: contentVersion,
                content: content,
                vaultID: vaultID,
                tagIds: tagIds?.toUUIDArray()
            ),
            metadata: encodeSystemFields()
        )
    }
}
