// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Backup
import Common
import CryptoKit

final class EncryptionHandlerImpl {
    private let mainRepository: MainRepository
    private let itemsInteractor: ItemsInteracting
    private let tagInteractor: TagInteracting

    init(mainRepository: MainRepository, itemsInteractor: ItemsInteracting, tagInteractor: TagInteracting) {
        self.mainRepository = mainRepository
        self.itemsInteractor = itemsInteractor
        self.tagInteractor = tagInteractor
    }
}

extension EncryptionHandlerImpl: EncryptionHandler {
    var currentCloudSchemaVersion: Int { Config.cloudSchemaVersion }
    
    func verifyEncryption(_ cloudData: VaultCloudData) -> EncryptionVerificationResult {
        guard let key = mainRepository.cachedExternalKey else {
            Log("EncryptionHandlerImpl: can't external key", module: .interactor, severity: .error)
            return .missingEncryption
        }
        
        guard let vaultID = mainRepository.selectedVault?.vaultID else {
            Log("EncryptionHandlerImpl: can't get vaultID", module: .interactor, severity: .error)
            return .missingEncryption
        }
        
        guard let data = Data(base64Encoded: cloudData.reference) else {
            Log("EncryptionHandlerImpl: can't encode data from cloud reference", module: .interactor, severity: .error)
            return .rejected
        }
        
        guard let reference = mainRepository.decrypt(data, key: key),
              let string = String(data: reference, encoding: .utf8),
              UUID(uuidString: string) == vaultID else {
            Log("EncryptionHandlerImpl: Password was changed - can't decode cloud reference!", module: .interactor)
            return .rejected
        }
        
        guard let seedHash = mainRepository.createSeedHashHexForExport() else {
            Log("EncryptionHandlerImpl: can't get seed hash hex", module: .interactor, severity: .error)
            return .missingEncryption
        }
        
        guard let kdfSpec = try? mainRepository.jsonDecoder.decode(KDFSpec.self, from: cloudData.kdfSpec) else {
            Log("EncryptionHandlerImpl: can't decode KDFSpec", module: .interactor, severity: .error)
            return .rejected
        }
        
        if cloudData.seedHash == seedHash && kdfSpec == KDFSpec.default {
            return .verified
        }
        return .rejected
    }
    
    func localEncryptedItemToCloudEncryptedData(_ localEncryptedItem: ItemEncryptedData) -> ItemEncryptedData? {
        guard let externalKey = mainRepository.cachedExternalKey else {
            Log("EncryptionHandlerImpl: can't get external key", module: .interactor, severity: .error)
            return nil
        }
        guard let localKey = mainRepository.getKey(
            isPassword: false,
            protectionLevel: localEncryptedItem.protectionLevel
        ) else {
            Log(
                "EncryptionHandlerImpl: can't get key for local encryption with level: \(localEncryptedItem.protectionLevel.rawValue)",
                module: .interactor,
                severity: .error
            )
            return nil
        }
        
        let content = localEncryptedItem.content
        guard let decryptedContent = decryptData(content, using: localKey) else {
            Log(
                "EncryptionHandlerImpl: can't decrypt item using local key",
                module: .interactor,
                severity: .error
            )
            return nil
        }
        
        guard let cloudEncrypted = encryptData(decryptedContent, using: externalKey) else {
            Log(
                "EncryptionHandlerImpl: can't encrypt item using external key",
                module: .interactor,
                severity: .error
            )
            return nil
        }
        
        var result = localEncryptedItem
        result.updateContent(cloudEncrypted)
        return result
    }
    
    func cloudEncryptedItemToLocalEncryptedItem(_ cloudEncryptedItem: ItemEncryptedData) -> ItemEncryptedData? {
        guard let externalKey = mainRepository.cachedExternalKey else {
            Log("EncryptionHandlerImpl: can't get external key", module: .interactor, severity: .error)
            return nil
        }
        guard let localKey = mainRepository.getKey(
            isPassword: false,
            protectionLevel: cloudEncryptedItem.protectionLevel
        ) else {
            Log(
                "EncryptionHandlerImpl: can't get key for local encryption with level: \(cloudEncryptedItem.protectionLevel.rawValue)",
                module: .interactor,
                severity: .error
            )
            return nil
        }
        
        let content = cloudEncryptedItem.content
        guard let decryptedContent = decryptData(content, using: externalKey) else {
            Log(
                "EncryptionHandlerImpl: can't decrypt item using external key",
                module: .interactor,
                severity: .error
            )
            return nil
        }
        
        guard let cloudEncrypted = encryptData(decryptedContent, using: localKey) else {
            Log(
                "EncryptionHandlerImpl: can't encrypt item using local key",
                module: .interactor,
                severity: .error
            )
            return nil
        }
        
        var result = cloudEncryptedItem
        result.updateContent(cloudEncrypted)
        return result
    }
    
    func tagToTagEncrypted(_ tag: ItemTagData) -> ItemTagEncryptedData? {
        guard let key = mainRepository.getKey(isPassword: false, protectionLevel: .normal),
              let nameEnc = encrypt(tag.name, using: key)
        else {
            Log("EncryptionHandlerImpl - can't encrypt Tag name", module: .interactor, severity: .error)
            return nil
        }
        return ItemTagEncryptedData(
            tagID: tag.id,
            vaultID: tag.vaultID,
            name: nameEnc,
            color: tag.color.rawValue,
            position: tag.position,
            modificationDate: tag.modificationDate
        )
    }
    
    func tagEncyptedToTag(_ tagEncrypted: ItemTagEncryptedData) -> ItemTagData? {
        guard let key = mainRepository.getKey(isPassword: false, protectionLevel: .normal),
              let name = decryptString(tagEncrypted.name, using: key)
        else {
            Log("EncryptionHandlerImpl - can't decrypt Tag name", module: .interactor, severity: .error)
            return nil
        }
        return ItemTagData(
            tagID: tagEncrypted.id,
            vaultID: tagEncrypted.vaultID,
            name: name,
            color: ItemTagColor(rawValue: tagEncrypted.color),
            position: tagEncrypted.position,
            modificationDate: tagEncrypted.modificationDate
        )
    }
    
    func vaultEncryptedDataToVaultRawData(_ vault: VaultEncryptedData) -> VaultRawData? {
        guard let seedHashHex = mainRepository.createSeedHashHexForExport(),
              let reference = mainRepository.createReferenceForExport(),
              let kdfSpec = try? mainRepository.jsonEncoder.encode(KDFSpec.default),
              let deviceID = mainRepository.deviceID,
              let deviceNames = try? mainRepository.jsonEncoder.encode([DeviceName(deviceID: deviceID, deviceName: mainRepository.deviceName)])
        else {
            return nil
        }
         
        return VaultRawData(
            vaultID: vault.vaultID,
            name: vault.name,
            createdAt: vault.createdAt,
            updatedAt: vault.updatedAt,
            deviceNames: deviceNames,
            deviceID: deviceID,
            schemaVersion: currentCloudSchemaVersion,
            seedHash: seedHashHex,
            reference: reference,
            kdfSpec: kdfSpec,
            zoneID: .from(vaultID: vault.vaultID)
        )
    }
    
    func updateCloudVault(_ cloudVault: VaultCloudData) -> VaultCloudData? {
        var cloudVault = cloudVault
        guard let deviceNames = mergeDeviceNames(cloudVault.deviceNames) else {
            return cloudVault
        }
        guard let seedHashHex = mainRepository.createSeedHashHexForExport(),
              let reference = mainRepository.createReferenceForExport(),
              let kdfSpec = try? mainRepository.jsonEncoder.encode(KDFSpec.default),
              let deviceID = mainRepository.deviceID
        else {
            return nil
        }
        cloudVault
            .update(
                deviceNames: deviceNames,
                deviceID: deviceID,
                seedHash: seedHashHex,
                reference: reference,
                kdfSpec: kdfSpec,
                updatedAt: mainRepository.currentDate,
                schemaVersion: currentCloudSchemaVersion
            )
        return cloudVault
    }
}

private extension EncryptionHandlerImpl {
    func mergeDeviceNames(_ deviceNames: Data) -> Data? {
        guard let deviceID = mainRepository.deviceID else {
            return nil
        }

        var currentDeviceNames = [DeviceName(deviceID: deviceID, deviceName: mainRepository.deviceName)]
        if let decodedDeviceNames = try? mainRepository.jsonDecoder.decode(
            [DeviceName].self,
            from: deviceNames
        ) {
            decodedDeviceNames.forEach { devName in
                if !currentDeviceNames.contains(where: { $0.deviceID == devName.deviceID }) {
                    currentDeviceNames.append(devName)
                }
            }
        }
        
        guard let newDeviceNames = try? mainRepository.jsonEncoder.encode(currentDeviceNames) else {
            return nil
        }
        
        return newDeviceNames
    }
    
    func encrypt(_ str: String, using key: SymmetricKey) -> Data? {
        guard let data = str.data(using: .utf8) else {
            Log("EncryptionHandlerImpl - can't encode string to data", module: .interactor, severity: .error)
            return nil
        }
        return encryptData(data, using: key)
    }
    
    func encryptData(_ data: Data, using key: SymmetricKey) -> Data? {
        mainRepository.encrypt(data, key: key)
    }
    
    func decryptData(_ data: Data, using key: SymmetricKey) -> Data? {
        mainRepository.decrypt(data, key: key)
    }
    
    func decryptString(_ data: Data, using key: SymmetricKey) -> String? {
        guard let decryptedData = decryptData(data, using: key) else {
            Log("EncryptionHandlerImpl - can't decrypt string to data", module: .interactor, severity: .error)
            return nil
        }
        return String(data: decryptedData, encoding: .utf8)
    }
    
    func createEncryptedIconType(
        iconType: PasswordIconType,
        key: SymmetricKey
    ) -> PasswordEncryptedIconType? {
        let eIconType = iconType.value
        var eIconDomain: Data?
        var eIconCustomURL: Data?
        var eLabelTitle: Data?
        var eLabelColor: UIColor?
        
        switch iconType {
        case .domainIcon(let domain):
            if let domain {
                guard let encrypted = encrypt(
                    domain,
                    using: key
                ) else {
                    Log("EncryptionHandlerImpl - can't encrypt iconURI", module: .interactor, severity: .error)
                    return nil
                }
                eIconDomain = encrypted
            }
        case .customIcon(let iconURI):
            guard let encrypted = encrypt(
                iconURI.absoluteString,
                using: key
            ) else {
                Log("EncryptionHandlerImpl - can't encrypt iconURI", module: .interactor, severity: .error)
                return nil
            }
            eIconCustomURL = encrypted
            
        case .label(let labelTitle, let labelColor):
            guard let encrypted = encrypt(labelTitle, using: key) else {
                Log("EncryptionHandlerImpl - can't encrypt labelTitle", module: .interactor, severity: .error)
                return nil
            }
            eLabelTitle = encrypted
            eLabelColor = labelColor
        }
        return PasswordEncryptedIconType(
            iconType: eIconType,
            iconDomain: eIconDomain,
            iconCustomURL: eIconCustomURL,
            labelTitle: eLabelTitle,
            labelColor: eLabelColor
        )
    }
    
    func decryptEncryptedIconType(
        iconType: PasswordEncryptedIconType,
        key: SymmetricKey
    ) -> PasswordIconType? {
        switch iconType {
        case .domainIcon(let domain):
            let decodedIconDomain: String?
            if let domain {
                guard let decoded = decryptString(domain, using: key) else {
                    Log("EncryptionHandlerImpl - can't decrypt iconURI", module: .interactor, severity: .error)
                    return nil
                }
                decodedIconDomain = decoded
            } else {
                decodedIconDomain = nil
            }
            return PasswordIconType.domainIcon(decodedIconDomain)
        case .customIcon(let iconURI):
            guard let decoded = decryptString(iconURI, using: key), let uri = URL(string: decoded) else {
                Log("EncryptionHandlerImpl - can't decrypt iconURI", module: .interactor, severity: .error)
                return nil
            }
            return PasswordIconType.customIcon(uri)
        case .label(let labelTitle, let labelColor):
            guard let decoded = decryptString(labelTitle, using: key) else {
                Log("EncryptionHandlerImpl - can't decrypt labelTitle", module: .interactor, severity: .error)
                return nil
            }
            return PasswordIconType.label(labelTitle: decoded, labelColor: labelColor)
        }
    }
    
    func createEncryptedURIs(
        from urisList: [PasswordURI],
        key: SymmetricKey
    ) -> PasswordEncryptedURIs? {
        let uris: Data
        let match: [PasswordURI.Match] = urisList.map({ $0.match })
        
        let urisUnpacked = urisList.map({ $0.uri })
        guard let urisJSON = try? mainRepository.jsonEncoder.encode(urisUnpacked) else {
            Log("EncryptionHandlerImpl - can't encode uris to JSON", module: .interactor, severity: .error)
            return nil
        }
        guard let encryptedURIs = encryptData(urisJSON, using: key) else {
            Log("EncryptionHandlerImpl - error encrypting uris JSON", module: .interactor, severity: .error)
            return nil
        }
        uris = encryptedURIs
        
        return PasswordEncryptedURIs(
            uris: uris,
            match: match
        )
    }
    
    func decryptURIs(
        from encryptedUri: PasswordEncryptedURIs,
        key: SymmetricKey
    ) -> [PasswordURI]? {
        let uri: [String]
        let match: [PasswordURI.Match] = encryptedUri.match
        
        let urisJSONEncryptedData = encryptedUri.uris
        guard let urisJSONData = decryptData(urisJSONEncryptedData, using: key),
              let urisJSON = try? mainRepository.jsonDecoder.decode([String].self, from: urisJSONData) else {
            Log("EncryptionHandlerImpl - can't decode uris to JSON", module: .interactor, severity: .error)
            return nil
        }
        uri = urisJSON
        
        guard uri.count == match.count && !uri.isEmpty else {
            return nil
        }
        
        var passwordURIs: [PasswordURI] = []
        for i in 0..<uri.count {
            let passwordURI = PasswordURI(uri: uri[i], match: match[i])
            passwordURIs.append(passwordURI)
        }
        
        return passwordURIs
    }
}
 
