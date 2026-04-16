// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common
import CryptoKit

public protocol VaultsInteracting: AnyObject {
    var hasVault: Bool { get }
    var defaultVaultID: VaultID { get }
    var defaultVault: VaultData? { get }
    func listVaults() -> [VaultData]
    func listEncryptedVaults() -> [VaultEncryptedData]
    func vault(for vaultID: VaultID) -> VaultData?
    func createNewVault(masterKey: Data, appKey: Data, vaultID: VaultID, name: String, color: String?, icon: String?, creationDate: Date?, modificationDate: Date?) -> VaultID?
    func changeVaultKeys(vaultID: VaultID, with masterKey: Data, appKey: Data) -> Bool
    func updateVault(_ vaultID: VaultID, name: String, color: String?, icon: String?, updatedAt: Date)
    func deleteVault(_ vaultID: VaultID)
    func saveStorage()
}

extension VaultsInteracting {
    
    func createNewVault(masterKey: Data, appKey: Data) -> VaultID? {
        createNewVault(masterKey: masterKey, appKey: appKey, vaultID: VaultID(), name: Config.mainVaultName, color: nil, icon: nil, creationDate: nil, modificationDate: nil)
    }
}

final class VaultsInteractor {
    private let mainRepository: MainRepository

    init(mainRepository: MainRepository) {
        self.mainRepository = mainRepository
    }
}

extension VaultsInteractor: VaultsInteracting {

    var hasVault: Bool {
        mainRepository.listEncryptedVaults().isEmpty == false
    }

    var defaultVaultID: VaultID {
        guard let vault = mainRepository.listEncryptedVaults().first else {
            preconditionFailure("VaultsInteractor.defaultVaultID accessed but no vaults exist. Ensure a vault is created during onboarding before accessing this property.")
        }
        return vault.vaultID
    }

    var defaultVault: VaultData? {
        guard let encrypted = mainRepository.getEncryptedVault(for: defaultVaultID) else { return nil }
        return decryptVault(encrypted)
    }

    func listVaults() -> [VaultData] {
        mainRepository.listEncryptedVaults().compactMap { decryptVault($0) }
    }
    
    func listEncryptedVaults() -> [VaultEncryptedData] {
        mainRepository.listEncryptedVaults()
    }

    func vault(for vaultID: VaultID) -> VaultData? {
        guard let encrypted = mainRepository.getEncryptedVault(for: vaultID) else { return nil }
        return decryptVault(encrypted)
    }

    func createNewVault(masterKey: Data, appKey: Data, vaultID: VaultID, name: String, color: String?, icon: String?, creationDate: Date?, modificationDate: Date?) -> VaultID? {
        let currentDate = mainRepository.currentDate
        let createdAt = creationDate ?? currentDate
        let updatedAt = {
            let date = modificationDate ?? currentDate
            if createdAt <= date {
                return date
            } else {
                return createdAt
            }
        }()

        guard
            let trustedKeyString = mainRepository.generateTrustedKeyForVaultID(
                vaultID,
                using: masterKey.hexEncodedString()
            ),
            let trustedKey = Data(hexString: trustedKeyString) else {
            Log("VaultsInteractor - createNewVault. Can't generate Trusted Key!", module: .interactor, severity: .error)
            return nil
        }
        guard let appKeySymm = mainRepository.createSymmetricKeyFromSecureEnclave(from: appKey) else {
            Log(
                "VaultsInteractor - createNewVault. Can't get Symmetric Key from App Key",
                module: .interactor,
                severity: .error
            )
            return nil
        }
        guard let encryptedTrustedKey = mainRepository.encrypt(trustedKey, key: appKeySymm) else {
            Log(
                "VaultsInteractor - createNewVault. Can't encrypt Trusted Key!",
                module: .interactor,
                severity: .error
            )
            return nil
        }
        let trustedKeySymm = mainRepository.createSymmetricKey(from: trustedKey)
        guard let nameData = name.data(using: .utf8),
              let encryptedName = mainRepository.encrypt(nameData, key: trustedKeySymm) else {
            Log(
                "VaultsInteractor - createNewVault. Can't encrypt vault name!",
                module: .interactor,
                severity: .error
            )
            return nil
        }

        mainRepository.createEncryptedVault(
            vaultID: vaultID,
            name: encryptedName,
            trustedKey: encryptedTrustedKey,
            createdAt: createdAt,
            updatedAt: updatedAt,
            color: color,
            icon: icon
        )
        mainRepository.saveEncryptedStorage()
        return vaultID
    }

    func changeVaultKeys(vaultID: VaultID, with masterKey: Data, appKey: Data) -> Bool {
        Log("VaultsInteractor - changeVaultKeys: \(vaultID)", module: .interactor)
        guard let vault = mainRepository.getEncryptedVault(for: vaultID) else {
            Log("VaultsInteractor - changeVaultKeys. No vault found for \(vaultID)!", module: .interactor, severity: .error)
            return false
        }
        let date = mainRepository.currentDate

        guard
            let trustedKeyString = mainRepository.generateTrustedKeyForVaultID(
                vaultID,
                using: masterKey.hexEncodedString()
            ),
            let trustedKey = Data(hexString: trustedKeyString) else {
            Log("VaultsInteractor - changeVaultKeys. Can't generate Trusted Key!", module: .interactor, severity: .error)
            return false
        }
        guard let appKeySymm = mainRepository.createSymmetricKeyFromSecureEnclave(from: appKey) else {
            Log(
                "VaultsInteractor - changeVaultKeys. Can't get Symmetric Key from App Key",
                module: .interactor,
                severity: .error
            )
            return false
        }
        guard let encryptedTrustedKey = mainRepository.encrypt(trustedKey, key: appKeySymm) else {
            Log(
                "VaultsInteractor - changeVaultKeys. Can't encrypt Trusted Key!",
                module: .interactor,
                severity: .error
            )
            return false
        }

        mainRepository.updateEncryptedVault(
            vaultID: vaultID,
            name: vault.name,
            trustedKey: encryptedTrustedKey,
            createdAt: vault.createdAt,
            updatedAt: date,
            color: vault.color,
            icon: vault.icon
        )
        mainRepository.saveEncryptedStorage()
        return true
    }

    func updateVault(_ vaultID: VaultID, name: String, color: String?, icon: String?, updatedAt: Date) {
        guard let vault = mainRepository.getEncryptedVault(for: vaultID),
              let encryptedName = encryptName(name, forVault: vaultID)
        else { return }
        mainRepository.updateEncryptedVault(
            vaultID: vaultID,
            name: encryptedName,
            trustedKey: vault.trustedKey,
            createdAt: vault.createdAt,
            updatedAt: updatedAt,
            color: color,
            icon: icon
        )
    }

    func deleteVault(_ vaultID: VaultID) {
        let encryptedItems = mainRepository.listEncryptedItems(in: vaultID)
        for item in encryptedItems {
            mainRepository.deleteItem(itemID: item.itemID)
            mainRepository.deleteEncryptedItem(itemID: item.itemID)
        }
        mainRepository.deleteAllEncryptedTags(in: vaultID)
        mainRepository.clearCachedKeys(for: vaultID)
        mainRepository.deleteEncryptedVault(vaultID)
    }

    func saveStorage() {
        mainRepository.saveEncryptedStorage()
        mainRepository.saveStorage()
    }
}

// MARK: - Encryption

private extension VaultsInteractor {
    func encryptName(_ name: String, forVault vaultID: VaultID) -> Data? {
        guard let key = mainRepository.getKey(isPassword: false, protectionLevel: .normal, forVault: vaultID),
              let nameData = name.data(using: .utf8),
              let encrypted = mainRepository.encrypt(nameData, key: key)
        else {
            Log("VaultsInteractor - can't encrypt vault name", module: .interactor, severity: .error)
            return nil
        }
        return encrypted
    }

    func decryptName(_ data: Data, forVault vaultID: VaultID) -> String? {
        guard let key = mainRepository.getKey(isPassword: false, protectionLevel: .normal, forVault: vaultID),
              let decrypted = mainRepository.decrypt(data, key: key),
              let name = String(data: decrypted, encoding: .utf8)
        else {
            Log("VaultsInteractor - can't decrypt vault name", module: .interactor, severity: .error)
            return nil
        }
        return name
    }

    func decryptVault(_ encrypted: VaultEncryptedData) -> VaultData? {
        guard let name = decryptName(encrypted.name, forVault: encrypted.vaultID) else { return nil }
        return VaultData(
            vaultID: encrypted.vaultID,
            name: name,
            createdAt: encrypted.createdAt,
            updatedAt: encrypted.updatedAt,
            isEmpty: encrypted.isEmpty,
            color: encrypted.color,
            icon: encrypted.icon
        )
    }
}
