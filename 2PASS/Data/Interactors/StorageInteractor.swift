// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Common
import CryptoKit
import LocalAuthentication

public protocol StorageInteracting: AnyObject {
    func initialize(completion: @escaping () -> Void)
    func createNewVault(masterKey: Data, appKey: Data, vaultID: VaultID, creationDate: Date?, modificationDate: Date?) -> VaultID?
    func updateExistingVault(with masterKey: Data, appKey: Data) -> Bool
    func clear()
}

extension StorageInteracting {
    
    func createNewVault(masterKey: Data, appKey: Data, vaultID: VaultID = VaultID()) -> VaultID? {
        createNewVault(masterKey: masterKey, appKey: appKey, vaultID: vaultID, creationDate: nil, modificationDate: nil)
    }
}

final class StorageInteractor {
    private let mainRepository: MainRepository
    private let autoFillInteractor: AutoFillCredentialsInteracting
    private let queue: DispatchQueue
    
    init(mainRepository: MainRepository, autoFillInteractor: AutoFillCredentialsInteracting) {
        self.mainRepository = mainRepository
        self.autoFillInteractor = autoFillInteractor
        self.queue = DispatchQueue(label: "InitializeStorageQueue", qos: .userInteractive, attributes: .concurrent)
    }
}

extension StorageInteractor: StorageInteracting {
    func initialize(completion: @escaping () -> Void) {
        Log(
            "StorageInteractor - initialize",
            module: .interactor
        )
        let vaults = mainRepository.listEncrypteVaults()
        guard let masterKey = mainRepository.empheralMasterKey else {
            Log(
                "StorageInteractor - initialize. Can't continue without Master Key!",
                module: .interactor,
                severity: .error
            )
            return
        }
        guard let appKey = mainRepository.appKey else {
            Log(
                "StorageInteractor - initialize. Can't continue without App Key!",
                module: .interactor,
                severity: .error
            )
            return
        }
        guard let secureKeyData = mainRepository.secureKey else {
            Log(
                "StorageInteractor - initialize. Can't continue without Secure Key!",
                module: .interactor,
                severity: .error
            )
            return
        }
        guard let trustedKeyData = mainRepository.trustedKey else {
            Log(
                "StorageInteractor - initialize. Can't continue without Trusted Key!",
                module: .interactor,
                severity: .error
            )
            return
        }
        let secureKey = mainRepository.createSymmetricKey(from: secureKeyData)
        let trustedKey = mainRepository.createSymmetricKey(from: trustedKeyData)
        
        var vaultID: VaultID
        if let vault = vaults.first {
            vaultID = vault.vaultID
        } else {
            guard let createdVaultID = createNewVault(masterKey: masterKey, appKey: appKey) else {
                Log(
                    "StorageInteractor - initialize. Can't create new vault!",
                    module: .interactor,
                    severity: .error
                )
                return
            }
            vaultID = createdVaultID
        }
        mainRepository.selectVault(vaultID)
        mainRepository.createInMemoryStorage()
        let passwords = mainRepository.listEncryptedPasswords(
            in: vaultID,
            excludeProtectionLevels: mainRepository.isMainAppProcess ? [] : Config.autoFillExcludeProtectionLevels
        )
        
        let tags = mainRepository.listEncryptedTags(in: vaultID)
        
        let group = DispatchGroup()
        
        for encryptedData in passwords {
            group.enter()
            queue.async { [weak self] in
                guard let self else {
                    group.leave()
                    return
                }
                let protectionLevel = encryptedData.protectionLevel
                let name = decryptData(
                    encryptedData.name,
                    protectionLevel: protectionLevel
                )
                let username = decryptData(
                    encryptedData.username,
                    protectionLevel: protectionLevel
                )
                let iconType: PasswordIconType = {
                    switch encryptedData.iconType {
                    case .domainIcon(let domain):
                        return .domainIcon(self.decryptData(domain, protectionLevel: protectionLevel))
                    case .customIcon(let iconURI):
                        if let urlString = self.decryptData(iconURI, protectionLevel: protectionLevel),
                           let url = URL(string: urlString) {
                            return .customIcon(url)
                        } else {
                            return .domainIcon(nil)
                        }
                    case .label(let labelTitle, let labelColor):
                        let labelTitle = self.decryptData(
                            labelTitle,
                            protectionLevel: protectionLevel
                        )
                        return .label(labelTitle: labelTitle ?? Config.defaultIconLabel, labelColor: labelColor)
                    }
                }()
                let notes = decryptData(encryptedData.notes, protectionLevel: protectionLevel)
                let uris = parseURIs(from: encryptedData, trustedKey: trustedKey, secureKey: secureKey)
                DispatchQueue.main.async {
                    self.mainRepository.createPassword(
                        passwordID: encryptedData.passwordID,
                        name: name,
                        username: username,
                        password: encryptedData.password,
                        notes: notes,
                        creationDate: encryptedData.creationDate,
                        modificationDate: encryptedData.modificationDate,
                        iconType: iconType,
                        trashedStatus: encryptedData.trashedStatus,
                        protectionLevel: protectionLevel,
                        uris: uris,
                        tagIds: encryptedData.tagIds
                    )
                    
                    group.leave()
                }
            }
        }
        
        for tag in tags {
            group.enter()
            
            let decryptedName = decryptData(tag.name, protectionLevel: .normal) ?? "" // no other fail available
            
            DispatchQueue.main.async {
                self.mainRepository.createTag(
                    .init(
                        tagID: tag.tagID,
                        vaultID: tag.vaultID,
                        name: decryptedName,
                        color: UIColor(hexString: tag.color),
                        position: tag.position,
                        modificationDate: tag.modificationDate
                    )
                )
                group.leave()
            }
        }
        
        group.notify(queue: .main) { [weak self] in
            Task.detached(priority: .utility) {
                try await self?.autoFillInteractor.syncSuggestions()
            }
            
            self?.mainRepository.saveStorage()
            completion()
        }
    }
    
    func clear() {
        Log("StorageInteractor - clear", module: .interactor)
        mainRepository.saveEncryptedStorage()
        mainRepository.clearVault()
        mainRepository.destroyInMemoryStorage()
    }
    
    func decryptData(
        _ data: Data?,
        protectionLevel: PasswordProtectionLevel) -> String? {
            guard let data else { return nil }
            guard let key = mainRepository.getKey(
                isPassword: false,
                protectionLevel: protectionLevel
            ) else {
                Log("StorageInteractor - can't get data or protection level", module: .interactor, severity: .error)
                return nil
            }
            
            guard let value = mainRepository.decrypt(data, key: key) else {
                Log("StorageInteractor - can't decrypt data", module: .interactor, severity: .error)
                return nil
            }
            return String(data: value, encoding: .utf8)
        }
    
    func createNewVault(masterKey: Data, appKey: Data, vaultID: VaultID = VaultID(), creationDate: Date?, modificationDate: Date?) -> VaultID? {
        let date = mainRepository.currentDate
        let createdAt = creationDate ?? date
        let updatedAt = modificationDate ?? date
        
        guard createdAt <= updatedAt else {
            Log("StorageInteractor - initialize. Creation date should be earlier than or equal to the modification date!", module: .interactor, severity: .error)
            return nil
        }
        
        guard
            let trustedKeyString = mainRepository.generateTrustedKeyForVaultID(
                vaultID,
                using: masterKey.hexEncodedString()
            ),
            let trustedKey = Data(hexString: trustedKeyString) else {
            Log("StorageInteractor - initialize. Can't generate Trusted Key!", module: .interactor, severity: .error)
            return nil
        }
        guard let appKeySymm = mainRepository.createSymmetricKeyFromSecureEnclave(from: appKey) else {
            Log(
                "StorageInteractor - initialize. Can't get Symmetric Key from App Key",
                module: .interactor,
                severity: .error
            )
            return nil
        }
        guard let encryptedTrustedKey = mainRepository.encrypt(trustedKey, key: appKeySymm) else {
            Log(
                "StorageInteractor - initialize. Can't encrypt Trusted Key!",
                module: .interactor,
                severity: .error
            )
            return nil
        }
        
        mainRepository.createEncryptedVault(
            vaultID: vaultID,
            name: Config.mainVaultName,
            trustedKey: encryptedTrustedKey,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
        mainRepository.saveEncryptedStorage()
        return vaultID
    }
    
    func updateExistingVault(with masterKey: Data, appKey: Data) -> Bool {
        Log("StorageInteractor - updating selected vault", module: .interactor)
        guard let vault = mainRepository.selectedVault else {
            Log("StorageInteractor - update. No selected vault!", module: .interactor, severity: .error)
            return false
        }
        let date = mainRepository.currentDate
        let vaultID = vault.vaultID
        
        Log(
            "StorageInteractor - current trustedKey: \(vault.trustedKey.hexEncodedString())",
            module: .interactor
        )
        
        guard
            let trustedKeyString = mainRepository.generateTrustedKeyForVaultID(
                vaultID,
                using: masterKey.hexEncodedString()
            ),
            let trustedKey = Data(hexString: trustedKeyString) else {
            Log("StorageInteractor - update. Can't generate Trusted Key!", module: .interactor, severity: .error)
            return false
        }
        guard let appKeySymm = mainRepository.createSymmetricKeyFromSecureEnclave(from: appKey) else {
            Log(
                "StorageInteractor - update. Can't get Symmetric Key from App Key",
                module: .interactor,
                severity: .error
            )
            return false
        }
        guard let encryptedTrustedKey = mainRepository.encrypt(trustedKey, key: appKeySymm) else {
            Log(
                "StorageInteractor - update. Can't encrypt Trusted Key!",
                module: .interactor,
                severity: .error
            )
            return false
        }
        
        Log(
            "StorageInteractor - new trustedKey: \(encryptedTrustedKey.hexEncodedString())",
            module: .interactor
        )
        
        mainRepository.updateEncryptedVault(
            vaultID: vaultID,
            name: vault.name,
            trustedKey: encryptedTrustedKey,
            createdAt: vault.createdAt,
            updatedAt: date
        )
        mainRepository.saveEncryptedStorage()
        mainRepository.selectVault(vaultID)
        
        Log("StorageInteractor - selected vault update!", module: .interactor)
        
        return true
    }
}

private extension StorageInteractor {
    func parseURIs(
        from encryptedData: PasswordEncryptedData,
        trustedKey: SymmetricKey,
        secureKey: SymmetricKey
    ) -> [PasswordURI]? {
        guard let passEncryptedUris = encryptedData.uris else { return nil }
        let protectionLevel = encryptedData.protectionLevel
        let urisData = passEncryptedUris.uris
        let matchList = passEncryptedUris.match
        
        guard
            let decryptedUris = decryptData(
                urisData,
                protectionLevel: protectionLevel
            ),
            let decryptedUrisData = decryptedUris.data(using: .utf8)
        else {
            return nil
        }
        
        guard
            let uris = try? mainRepository.jsonDecoder.decode(
                [String].self,
                from: decryptedUrisData
            )
        else { return nil }
        
        guard uris.count == matchList.count else {
            return nil
        }
        return uris.enumerated().compactMap { index, uri in
            guard let match = matchList[safe: index] else {
                return nil
            }
            return PasswordURI(uri: uri, match: match)
        }
    }
}
