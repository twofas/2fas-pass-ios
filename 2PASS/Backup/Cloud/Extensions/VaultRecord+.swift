// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common
import CloudKit

extension VaultRecord {
    static func recreate(
        jsonEncoder: JSONEncoder,
        vaultID: VaultID,
        name: String,
        createdAt: Date,
        updatedAt: Date,
        metadata: Data,
        data: VaultEncryptedData,
        deviceNames: [RecordDataVault.DeviceName],
        deviceID: DeviceID,
        schemaVersion: Int,
        seedHash: String,
        reference: String,
        kdfSpec: KDFSpec
    ) -> CKRecord? {
        guard let deviceNames = try? jsonEncoder.encode(deviceNames),
              let kdfSpec = try? jsonEncoder.encode(kdfSpec) else {
            return nil
        }
        return recreate(
            with: metadata,
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
    }
    
    func toRecordData() -> VaultCloudData {
        .init(
            vaultID: vaultID,
            name: name,
            createdAt: createdAt,
            updatedAt: updatedAt,
            metadata: encodeSystemFields(),
            deviceNames: deviceNames,
            deviceID: deviceID,
            schemaVersion: schemaVersion,
            seedHash: seedHash,
            reference: reference,
            kdfSpec: kdfSpec
        )
    }
    
    func toRawData() -> VaultRawData? {
        guard let zoneID = ckRecord?.recordID.zoneID else {
            return nil
        }
        return .init(
            vaultID: vaultID,
            name: name,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deviceNames: deviceNames,
            deviceID: deviceID,
            schemaVersion: schemaVersion,
            seedHash: seedHash,
            reference: reference,
            kdfSpec: kdfSpec,
            zoneID: zoneID
        )
    }
    
    static func recreate(from vault: VaultCloudData) -> CKRecord? {
        VaultRecord.recreate(
            with: vault.metadata,
            vaultID: vault.vaultID,
            name: vault.name,
            createdAt: vault.createdAt,
            updatedAt: vault.updatedAt,
            deviceNames: vault.deviceNames,
            deviceID: vault.deviceID,
            schemaVersion: vault.schemaVersion,
            seedHash: vault.seedHash,
            reference: vault.reference,
            kdfSpec: vault.kdfSpec
        )
    }
    
    static func create(from vault: VaultRawData) -> VaultRecord? {
        guard let ckRecord = create(
            zoneID: vault.zoneID,
            vaultID: vault.vaultID,
            name: vault.name,
            createdAt: vault.createdAt,
            updatedAt: vault.updatedAt,
            deviceNames: vault.deviceNames,
            deviceID: vault.deviceID,
            schemaVersion: vault.schemaVersion,
            seedHash: vault.seedHash,
            reference: vault.reference,
            kdfSpec: vault.kdfSpec
        ) else { return nil }
        return VaultRecord(record: ckRecord)
    }
}
