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
    @MainActor func loadStore() async
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
    private let migrationInteractor: MigrationInteracting
    private let queue: DispatchQueue
    
    init(mainRepository: MainRepository, autoFillInteractor: AutoFillCredentialsInteracting, migrationInteractor: MigrationInteracting) {
        self.mainRepository = mainRepository
        self.autoFillInteractor = autoFillInteractor
        self.migrationInteractor = migrationInteractor
        self.queue = DispatchQueue(label: "InitializeStorageQueue", qos: .userInteractive, attributes: .concurrent)
    }
}

extension StorageInteractor: StorageInteracting {
    
    @MainActor
    func loadStore() async {
        await withCheckedContinuation { continuation in
            mainRepository.loadEncryptedStore {
                continuation.resume()
            }
        }
    }
    
    func initialize(completion: @escaping () -> Void) {
        Log(
            "StorageInteractor - initialize",
            module: .interactor
        )
        
        if migrationInteractor.requiresReencryptionMigration() {
            Task { @MainActor in
                guard await migrationInteractor.loadStoreWithReencryptionMigration() else {
                    fatalError("Failed to load Encrypted store with reencryption migration")
                }
                performInitialize(completion: completion)
            }
        } else {
            performInitialize(completion: completion)
        }
    }
    
    private func performInitialize(completion: @escaping () -> Void) {
        Log(
            "StorageInteractor - perform initialize",
            module: .interactor
        )
        
        let vaults = mainRepository.listEncryptedVaults()
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
        let items = mainRepository.listEncryptedItems(
            in: vaultID,
            excludeProtectionLevels: mainRepository.isMainAppProcess ? [] : Config.autoFillExcludeProtectionLevels
        )
        
        let tags = mainRepository.listEncryptedTags(in: vaultID)
        
        let group = DispatchGroup()
        
        for encryptedData in items {
            group.enter()
            queue.async { [weak self] in
                guard let self else {
                    group.leave()
                    return
                }
                let protectionLevel = encryptedData.protectionLevel
                
                let (name, contentData) = decryptContentData(
                    encryptedData.content,
                    protectionLevel: protectionLevel
                )
                
                guard let contentData else {
                    group.leave()
                    return
                }
                DispatchQueue.main.async {
                    self.mainRepository.createItem(
                        itemID: encryptedData.itemID,
                        creationDate: encryptedData.creationDate,
                        modificationDate: encryptedData.modificationDate,
                        trashedStatus: encryptedData.trashedStatus,
                        protectionLevel: encryptedData.protectionLevel,
                        tagIds: encryptedData.tagIds,
                        name: name,
                        contentType: encryptedData.contentType,
                        contentVersion: encryptedData.contentVersion,
                        content: contentData
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
        protectionLevel: ItemProtectionLevel) -> String? {
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
    
    func decryptContentData(
        _ data: Data?,
        protectionLevel: ItemProtectionLevel) -> (name: String?, content: Data?) {
            guard let data else { return (nil, nil) }
            guard let key = mainRepository.getKey(
                isPassword: false,
                protectionLevel: protectionLevel
            ) else {
                Log("StorageInteractor - can't get data or protection level", module: .interactor, severity: .error)
                return (nil, nil)
            }
            
            guard let value = mainRepository.decrypt(data, key: key) else {
                Log("StorageInteractor - can't decrypt data", module: .interactor, severity: .error)
                return (nil, nil)
            }

            return (mainRepository.extractItemName(fromContent: value), value)
        }
    
    func createNewVault(masterKey: Data, appKey: Data, vaultID: VaultID = VaultID(), creationDate: Date?, modificationDate: Date?) -> VaultID? {
        let date = mainRepository.currentDate
        let createdAt = creationDate ?? date
        let updatedAt = modificationDate ?? date
        
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
