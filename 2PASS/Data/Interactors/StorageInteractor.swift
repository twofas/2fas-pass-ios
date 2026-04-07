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
    func clear()
}

final class StorageInteractor {
    private let mainRepository: MainRepository
    private let vaultsInteractor: VaultsInteracting
    private let autoFillInteractor: AutoFillCredentialsInteracting
    private let migrationInteractor: MigrationInteracting
    private let queue: DispatchQueue

    init(
        mainRepository: MainRepository,
        vaultsInteractor: VaultsInteracting,
        autoFillInteractor: AutoFillCredentialsInteracting,
        migrationInteractor: MigrationInteracting
    ) {
        self.mainRepository = mainRepository
        self.vaultsInteractor = vaultsInteractor
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
        
        var vaultIDs: [VaultID]
        if vaults.isEmpty {
            guard let createdVaultID = vaultsInteractor.createNewVault(masterKey: masterKey, appKey: appKey, vaultID: VaultID(), name: Config.mainVaultName, color: nil, icon: nil, creationDate: nil, modificationDate: nil) else {
                Log(
                    "StorageInteractor - initialize. Can't create new vault!",
                    module: .interactor,
                    severity: .error
                )
                return
            }
            vaultIDs = [createdVaultID]
        } else {
            vaultIDs = vaults.map(\.vaultID)
        }

        mainRepository.createInMemoryStorage()

        let excludeProtectionLevels: Set<ItemProtectionLevel>? =
            mainRepository.isMainAppProcess ? nil : Config.autoFillExcludeProtectionLevels

        let group = DispatchGroup()

        for vaultID in vaultIDs {
            let items = mainRepository.listEncryptedItems(
                in: vaultID,
                itemIDs: nil,
                excludeProtectionLevels: excludeProtectionLevels
            )

            let tags = mainRepository.listEncryptedTags(in: vaultID)

            for encryptedData in items {
                group.enter()
                queue.async { [weak self] in
                    guard let self else {
                        group.leave()
                        return
                    }

                    let (name, contentData) = decryptContentData(
                        encryptedData.content,
                        protectionLevel: encryptedData.protectionLevel,
                        vaultID: vaultID
                    )

                    guard let contentData else {
                        group.leave()
                        return
                    }
                    DispatchQueue.main.async {
                        self.mainRepository.createItem(
                            itemID: encryptedData.itemID,
                            vaultID: encryptedData.vaultID,
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

                let decryptedName = decryptData(tag.name, protectionLevel: .normal, vaultID: vaultID) ?? ""

                DispatchQueue.main.async {
                    self.mainRepository.createTag(
                        .init(
                            tagID: tag.tagID,
                            vaultID: tag.vaultID,
                            name: decryptedName,
                            color: ItemTagColor(rawValue: tag.color),
                            position: tag.position,
                            modificationDate: tag.modificationDate
                        )
                    )
                    group.leave()
                }
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
        mainRepository.destroyInMemoryStorage()
    }
    
    func decryptData(
        _ data: Data?,
        protectionLevel: ItemProtectionLevel,
        vaultID: VaultID) -> String? {
            guard let data else { return nil }
            guard let key = mainRepository.getKey(
                isPassword: false,
                protectionLevel: protectionLevel,
                forVault: vaultID
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
        protectionLevel: ItemProtectionLevel,
        vaultID: VaultID) -> (name: String?, content: Data?) {
            guard let data else { return (nil, nil) }
            guard let key = mainRepository.getKey(
                isPassword: false,
                protectionLevel: protectionLevel,
                forVault: vaultID
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
}
