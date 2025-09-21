// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common
import LocalAuthentication
import CryptoKit

public enum VerifyMasterPasswordError: Error {
    case noConfig
    case errorCreatingMasterKey
}

public enum SetWordsError: Error {
    case wrongWords
    case general
}

public protocol ProtectionInteracting: AnyObject {
    var hasDeviceID: Bool { get }
    func setupDeviceID()
    
    var words: [String]? { get }
    var seed: Seed? { get }
    var salt: Salt? { get }
    var masterKey: MasterKey? { get }
    var masterPassword: String? { get }
    var entropy: Entropy? { get }
    
    var hasVault: Bool { get }
    var vaultHasTrustedPasswords: Bool { get }
    var hasEncryptedEntropy: Bool { get }
    func restoreEntropy()
    func saveEntropy()
    func clearEntropy()
    func clearApp()
    
    var hasBiometryKey: Bool { get }
    
    var hasAppKey: Bool { get }
    func createAppKey()
    
    func generateEntropy()
    func createSeed()
    func createSalt()
    func verifyMasterPassword(_ masterPassword: String) -> Bool
    func setMasterKey(for masterPassword: String)
    func setMasterKey(_ masterKey: MasterKey)
    func setMasterPassword(_ masterPassword: MasterPassword)
    func masterKey(from masterPassword: MasterPassword, entropy: Entropy, kdfSpec: KDFSpec) -> MasterKey?
    func setupKeys()
    func selectVault()
    func clearAfterInit()
    func updateExistingVault()
    
    var hasEncryptionReference: Bool { get }
    func createNewVault(with vaultID: VaultID, creationDate: Date?, modificationDate: Date?)
    func saveEncryptionReference()
    
    func getAllWords() -> [String]
    func setWords(_ words: [String], masterPassword: MasterPassword?) -> Result<Void, SetWordsError>
    func setEntropy(_ entropy: Entropy, masterKey: MasterKey?) -> Bool
    func wordsToEntropy(_ words: [String]) -> Entropy?
    
    func recreateSeedSaltWordsMasterKey() -> Bool
    
    func clearMasterKey()
    func clearMasterKeyEncrypted()
    func clearAppKeyEncryptedStorage()
    
    func createExternalSymmetricKey(from masterKey: MasterKey, vaultID: VaultID) -> SymmetricKey?
}

extension ProtectionInteracting {
    
    func createNewVault(with vaultID: VaultID) {
        createNewVault(with: vaultID, creationDate: nil, modificationDate: nil)
    }
}

final class ProtectionInteractor {
    private let mainRepository: MainRepository
    private let storageInteractor: StorageInteracting
    
    init(mainRepository: MainRepository, storageInteractor: StorageInteracting) {
        self.mainRepository = mainRepository
        self.storageInteractor = storageInteractor
    }
}

extension ProtectionInteractor: ProtectionInteracting {
    var hasDeviceID: Bool {
        mainRepository.deviceID != nil
    }
    
    func setupDeviceID() {
        Log("ProtectionInteractor: Setup Device ID", module: .interactor)
        let deviceID = mainRepository.generateUUID()
        mainRepository.saveDeviceID(deviceID)
    }
    
    var words: [String]? { mainRepository.words }
    var seed: Seed? { mainRepository.seed }
    var salt: Salt? { mainRepository.salt }
    var masterKey: MasterKey? { mainRepository.empheralMasterKey }
    var entropy: Entropy? { mainRepository.entropy }
    
    var masterPassword: String? {
        mainRepository.masterPassword
    }
    
    var hasVault: Bool {
        !mainRepository.listEncryptedVaults().isEmpty
    }
    
    var vaultHasTrustedPasswords: Bool {
        guard let vault = mainRepository.listEncryptedVaults().first else {
            return false
        }
        guard !vault.isEmpty else {
            return false
        }
        return !mainRepository.listEncryptedItems(in: vault.vaultID)
            .filter({ $0.protectionLevel != .topSecret }).isEmpty
    }
    
    var hasEncryptedEntropy: Bool {
        mainRepository.hasMasterKeyEntropy
    }
    
    var hasAppKey: Bool {
        mainRepository.appKey != nil
    }
    
    func clearMasterKeyEncrypted() {
        Log("ProtectionInteractor: Clear stored Master Key", module: .interactor)
        mainRepository.clearMasterKey()
    }
    
    func clearAppKeyEncryptedStorage() {
        Log("ProtectionInteractor: Clear Master Key Entropy and Encryption Reference", module: .interactor)
        mainRepository.clearMasterKeyEntropy()
        mainRepository.clearEncryptionReference()
    }
    
    func clearApp() {
        Log("ProtectionInteractor: Clear All!", module: .interactor)
        mainRepository.clearAppKey()
        mainRepository.clearBiometryKey()
        mainRepository.clearMasterKey()
        mainRepository.clearEncryptionReference()
        mainRepository.clearEntropy()
        mainRepository.clearMasterKeyEntropy()
        mainRepository.clearAllEmphemeral()
        mainRepository.deleteAllVaults()
    }
    
    var hasBiometryKey: Bool {
        mainRepository.biometryKey != nil
    }
    
    var hasEncryptionReference: Bool {
        mainRepository.hasEncryptionReference
    }
    
    func createAppKey() {
        Log("ProtectionInteractor: Create App Key", module: .interactor)
        guard let accessControl = mainRepository.createSecureEnclaveAccessControl(needAuth: false) else {
            Log(
                "ProtectionInteractor: Can't create Access Control for App Key creation",
                module: .interactor,
                severity: .error
            )
            return
        }
        mainRepository.createSecureEnclavePrivateKey(
            accessControl: accessControl
        ) { [weak self] key in
            guard let key else {
                Log("ProtectionInteractor: Error while creating App Key", module: .interactor, severity: .error)
                return
            }
            Log("ProtectionInteractor: Saving App Key", module: .interactor)
            self?.mainRepository.saveAppKey(key)
        }
    }
    
    func restoreEntropy() {
        Log("ProtectionInteractor: Restoring Entropy", module: .interactor)
        guard let entropy = mainRepository.masterKeyEntropy else {
            Log("ProtectionInteractor: No Entropy to restore!", module: .interactor)
            return
        }
        Log(
            "ProtectionInteractor: Restored Entropy: \(entropy.hexEncodedString())",
            module: .interactor
        )
        mainRepository.setEntropy(entropy)
    }
    
    func clearEntropy() {
        mainRepository.clearEntropy()
    }
    
    func saveEntropy() {
        Log("ProtectionInteractor: Saving Entropy", module: .interactor)
        guard let entropy = mainRepository.entropy else {
            Log("ProtectionInteractor: Error while saving Entropy", module: .interactor, severity: .error)
            return
        }
        
        Log(
            "ProtectionInteractor: Saving Entropy: \(entropy.hexEncodedString())",
            module: .interactor
        )
        mainRepository.saveMasterKeyEntropy(entropy)
    }
    
    func generateEntropy() {
        Log("ProtectionInteractor: Generating Entropy", module: .interactor)
        guard let entropy = mainRepository.generateEntropy() else {
            Log("ProtectionInteractor: Error while generating Entropy", severity: .error)
            return
        }
        Log(
            "ProtectionInteractor: Generated Entropy: \(entropy.hexEncodedString())",
            module: .interactor
        )
        mainRepository.setEntropy(entropy)
    }
    
    func createSeed() {
        Log("ProtectionInteractor: Creating Seed", module: .interactor)
        guard let entropy = mainRepository.entropy else {
            Log(
                "ProtectionInteractor: Error creating Seed - Entropy is missing!",
                module: .interactor,
                severity: .error
            )
            return
        }
        let seed = mainRepository.createSeed(from: entropy)
        Log(
            "ProtectionInteractor: Seed: \(seed.hexEncodedString())",
            module: .interactor
        )
        mainRepository.setSeed(seed)
    }
    
    func createSalt() {
        Log("ProtectionInteractor: Creating Salt", module: .interactor)
        guard let entropy = mainRepository.entropy else {
            Log(
                "ProtectionInteractor: Error while getting Entropy - it's missing",
                module: .interactor,
                severity: .error
            )
            return
        }
        guard let seed = mainRepository.seed else {
            Log("ProtectionInteractor: Error while creating Salt - missing Seed", module: .interactor, severity: .error)
            return
        }
        Log(
            "ProtectionInteractor: Entropy: \(entropy.hexEncodedString()), Seed: \(seed.hexEncodedString())",
            module: .interactor
        )
        let groups = mainRepository.create11BitPacks(from: entropy, seed: seed)
        Log("ProtectionInteractor: 11Bit packs from Entropy and Seed: \(groups)", module: .interactor)
        
        guard let words = mainRepository.createWords(from: groups) else {
            Log("ProtectionInteractor: Error while getting Words", module: .interactor, severity: .error)
            return
        }
        Log("ProtectionInteractor: Words: \(words)", module: .interactor)
        mainRepository.setWords(words)
        
        Log("ProtectionInteractor: Creating Salt", module: .interactor)
        guard let salt = mainRepository.createSalt(from: words) else {
            Log("Error while creating Salt", module: .interactor, severity: .error)
            return
        }
        
        Log("ProtectionInteractor: Salt: \(salt.hexEncodedString())", module: .interactor)
        mainRepository.setSalt(salt)
    }
    
    func saveEncryptionReference() {
        Log("ProtectionInteractor: Save Encryption Reference", module: .interactor)
        guard let deviceID = mainRepository.deviceID else {
            Log(
                "ProtectionInteractor: Error while getting DeviceID for saving Encryption Reference",
                module: .interactor,
                severity: .error
            )
            return
        }
        
        Log("ProtectionInteractor: DeviceID: \(deviceID)", module: .interactor)
        Log("ProtectionInteractor: Getting Master Key", module: .interactor)
        
        guard let masterKey = mainRepository.empheralMasterKey else {
            Log(
                "ProtectionInteractor: Error while generating Master Key for saving Encryption Reference",
                module: .interactor,
                severity: .error
            )
            return
        }
        Log(
            "ProtectionInteractor: Saving Encryption Reference using DeviceID: \(deviceID) and Master Key: \(masterKey.hexEncodedString())",
            module: .interactor
        )
        mainRepository.saveEncryptionReference(deviceID, masterKey: masterKey)
    }
    
    func verifyMasterPassword(_ masterPassword: String) -> Bool {
        restoreEntropy()
        createSeed()
        createSalt()
        Log("ProtectionInteractor: Verifying Master Password: \(masterPassword)", module: .interactor)
        
        guard let deviceID = mainRepository.deviceID else {
            Log(
                "ProtectionInteractor: Error while getting DeviceID for Master Password verification",
                module: .interactor,
                severity: .error
            )
            return false
        }
        Log("ProtectionInteractor: DeviceID: \(deviceID)", module: .interactor)
        Log("ProtectionInteractor: Creating Master Key", module: .interactor)
        
        guard let masterKey = createMasterKey(using: masterPassword) else {
            Log(
                "ProtectionInteractor: Error while generating Master Key for Master Password verification",
                module: .interactor,
                severity: .error
            )
            return false
        }
        Log(
            "ProtectionInteractor: Veryfing Encryption Reference using Master Key \(masterKey.hexEncodedString()) and DeviceID: \(deviceID)",
            module: .interactor
        )
        let value = mainRepository.verifyEncryptionReference(using: masterKey, with: deviceID)
        Log("ProtectionInteractor: Verification: \(value, privacy: .private)", module: .interactor)
        return value
    }
    
    func setMasterKey(_ masterKey: MasterKey) {
        Log(
            "ProtectionInteractor: Setting Master Key: \(masterKey.hexEncodedString())",
            module: .interactor
        )
        mainRepository.setEmpheralMasterKey(masterKey)
    }
    
    func setMasterKey(for masterPassword: String) {
        Log(
            "ProtectionInteractor: Setting Master Key for Master Password: \(masterPassword)",
            module: .interactor
        )
        guard let masterKey = createMasterKey(using: masterPassword) else {
            Log("ProtectionInteractor: Error while setting Master Key", module: .interactor, severity: .error)
            return
        }
        Log(
            "ProtectionInteractor: Setting Master Key for Master Password: \(masterKey.hexEncodedString())",
            module: .interactor
        )
        mainRepository.setEmpheralMasterKey(masterKey)
    }
    
    func masterKey(from masterPassword: MasterPassword, entropy: Entropy, kdfSpec: KDFSpec = .default) -> MasterKey? {
        guard let masterKey = createMasterKey(using: masterPassword, entropy: entropy, kdfSpec: kdfSpec) else {
            Log(
                "ProtectionInteractor: Error while creating Master Key using passed entropy",
                module: .interactor,
                severity: .error
            )
            return nil
        }
        return masterKey
    }
    
    func setMasterPassword(_ masterPassword: MasterPassword) {
        Log("ProtectionInteractor: Set Master Password: \(masterPassword)", module: .interactor)
        mainRepository.setMasterPassword(masterPassword)
    }
    
    func setupKeys() {
        Log("ProtectionInteractor: Setup Keys. Getting Master Key", module: .interactor)
        guard let masterKey = mainRepository.empheralMasterKey else {
            Log("Error while getting Master Key - it's missing", severity: .error)
            return
        }
        Log("ProtectionInteractor: Master Key: \(masterKey.hexEncodedString())", module: .interactor)
        Log("ProtectionInteractor: Getting selected Vault", module: .interactor)
        
        guard let vault = mainRepository.selectedVault else {
            Log("Error while getting selected Vault - it's missing", severity: .error)
            return
        }
        Log("ProtectionInteractor: Vault: \(vault.vaultID). Creating Keys", module: .interactor)
        
        Log("ProtectionInteractor: Getting Trusted Key", module: .interactor)
        guard let trustedKey = mainRepository.generateTrustedKeyForVaultID(
            vault.vaultID,
            using: masterKey.hexEncodedString()
        ), let trustedKeyData = Data(hexString: trustedKey)
        else {
            Log("Error while generating Trusted Key", severity: .error)
            return
        }
        Log("ProtectionInteractor: Trusted Key: \(trustedKey)", module: .interactor)
        mainRepository.setTrustedKey(trustedKeyData)
        
        guard let secureKey = mainRepository.generateSecureKeyForVaultID(
            vault.vaultID,
            using: masterKey.hexEncodedString()
        ), let secureKeyData = Data(hexString: secureKey)
        else {
            Log("Error while generating Secure Key", severity: .error)
            return
        }
        Log("ProtectionInteractor: Secure Key: \(secureKey)", module: .interactor)
        mainRepository.setSecureKey(secureKeyData)
        
        Log("ProtectionInteractor: Getting External Key", module: .interactor)
        guard let externalKey = mainRepository.generateExternalKeyForVaultID(
            vault.vaultID,
            using: masterKey.hexEncodedString()
        ), let externalKeyData = Data(hexString: externalKey)
        else {
            Log("ProtectionInteractor: Error while generating External Key", module: .interactor, severity: .error)
            return
        }
        Log("ProtectionInteractor: External Key: \(externalKey)", module: .interactor)
        mainRepository.setExternalKey(externalKeyData)
        
        // Caching keys - Keychain access is expensive
        mainRepository.preparedCachedKeys()
    }
    
    func selectVault() {
        Log("ProtectionInteractor: Selecting Vault", module: .interactor)
        guard let vault = mainRepository.listEncryptedVaults().first else {
            Log("ProtectionInteractor: Can't find any Vault", module: .interactor, severity: .error)
            return
        }
        Log("ProtectionInteractor: Found Vault: \(vault.vaultID)", module: .interactor)
        mainRepository.selectVault(vault.vaultID)
    }
    
    func clearMasterKey() {
        Log("ProtectionInteractor: Clearing Master Key", module: .interactor)
        mainRepository.clearEmpheralMasterKey()
    }
    
    func clearAfterInit() {
        Log("ProtectionInteractor: Clearing after init", module: .interactor)
        mainRepository.clearEmpheralMasterKey()
        mainRepository.clearSalt()
        mainRepository.clearWords()
        mainRepository.clearMasterPassword()
        mainRepository.clearEntropy()
    }
    
    func createNewVault(with vaultID: VaultID, creationDate: Date?, modificationDate: Date?) {
        Log("ProtectionInteractor: Creating new Vault", module: .interactor)
        Log("ProtectionInteractor: Getting Master Key", module: .interactor)
        guard let masterKey = mainRepository.empheralMasterKey else {
            Log("ProtectionInteractor: Error while getting Master Key - it's missing", severity: .error)
            return
        }
        Log("ProtectionInteractor: Master Key: \(masterKey.hexEncodedString())", module: .interactor)
        Log("ProtectionInteractor: Getting App Key", module: .interactor)
        
        guard let appKey = mainRepository.appKey else {
            Log("ProtectionInteractor: Error while getting App Key - it's missing", severity: .error)
            return
        }
        
        Log("ProtectionInteractor: App Key obtained, creating new Vault", module: .interactor)
        
        guard storageInteractor.createNewVault(masterKey: masterKey, appKey: appKey, vaultID: vaultID, creationDate: creationDate, modificationDate: modificationDate) != nil else {
            Log("ProtectionInteractor: Error while creating new Vault", severity: .error)
            return
        }
        Log("ProtectionInteractor: New Vault created successfuly", module: .interactor)
    }
    
    func updateExistingVault() {
        Log("ProtectionInteractor: Updating extisting Vault", module: .interactor)
        Log("ProtectionInteractor: Getting Master Key", module: .interactor)
        guard let masterKey = mainRepository.empheralMasterKey else {
            Log("ProtectionInteractor: Error while getting Master Key - it's missing", severity: .error)
            return
        }
        Log("ProtectionInteractor: Master Key: \(masterKey.hexEncodedString())", module: .interactor)
        Log("ProtectionInteractor: Getting App Key", module: .interactor)
        
        guard let appKey = mainRepository.appKey else {
            Log("ProtectionInteractor: Error while getting App Key - it's missing", severity: .error)
            return
        }
        
        Log("ProtectionInteractor: App Key obtained, updating Vault", module: .interactor)

        guard storageInteractor.updateExistingVault(with: masterKey, appKey: appKey) else {
            Log("ProtectionInteractor: Error while updating exisitng Vault", severity: .error)
            return
        }
        Log("ProtectionInteractor: Vault updated successfuly", module: .interactor)
    }
    
    func getAllWords() -> [String] {
        guard let words = mainRepository.importBIP0039Words() else {
            Log("ProtectionInteractor: Error while importing BIP 0039 Words from file", severity: .error)
            return []
        }
        return words
    }
    
    func setEntropy(_ entropy: Entropy, masterKey: MasterKey?) -> Bool {
        Log(
            "ProtectionInteractor: Setting Entropy: \(entropy.base64EncodedString()) with Master Password: \(masterPassword ?? "<none>")",
            module: .interactor
        )
        
        let seed = mainRepository.createSeed(from: entropy)
        Log(
            "ProtectionInteractor: Seed: \(seed.hexEncodedString())",
            module: .interactor
        )
        
        let bitPacks = mainRepository.create11BitPacks(from: entropy, seed: seed)
        
        guard let words = mainRepository.createWords(from: bitPacks) else {
            Log("ProtectionInteractor: Error while creating words", module: .interactor, severity: .error)
            return false
        }
        
        Log("ProtectionInteractor: Creating salt", module: .interactor)
        guard let salt = mainRepository.createSalt(from: words) else {
            Log("ProtectionInteractor: Error while creating Salt", module: .interactor, severity: .error)
            return false
        }
        Log("ProtectionInteractor: Salt: \(salt.hexEncodedString())", module: .interactor)
        
        if let masterKey {
            mainRepository.setEmpheralMasterKey(masterKey)
        }
        
        mainRepository.setSeed(seed)
        mainRepository.setSalt(salt)
        mainRepository.setWords(words)
        mainRepository.setEntropy(entropy)
        mainRepository.saveMasterKeyEntropy(entropy)
        
        return true
    }
    
    func setWords(_ words: [String], masterPassword: MasterPassword?) -> Result<Void, SetWordsError> {
        Log(
            "ProtectionInteractor: Setting words: \(words) with Master Password: \(masterPassword ?? "<none>")",
            module: .interactor
        )
        mainRepository.setWords(words)
        if let masterPassword {
            mainRepository.setMasterPassword(masterPassword)
        }
        Log("ProtectionInteractor: Creating salt", module: .interactor)
        guard let salt = mainRepository.createSalt(from: words) else {
            Log("ProtectionInteractor: Error while creating Salt", module: .interactor, severity: .error)
            return .failure(.general)
        }
        Log("ProtectionInteractor: Salt: \(salt.hexEncodedString())", module: .interactor)
        mainRepository.setSalt(salt)
        
        guard let (entropy, oldCRC) = mainRepository.convertWordsTo4BitPacksAndCRC(words) else {
            Log("ProtectionInteractor: Error while creating Entropy and CRC", module: .interactor, severity: .error)
            return .failure(.general)
        }
        
        Log(
            "ProtectionInteractor: Entropy: \(entropy.hexEncodedString()), CRC: \(oldCRC, privacy: .private)",
            module: .interactor
        )
        
        let seed = mainRepository.createSeed(from: entropy)
        Log(
            "ProtectionInteractor: Seed: \(seed.hexEncodedString())",
            module: .interactor
        )
        let newCRC = mainRepository.createCRC(from: seed)
        Log(
            "ProtectionInteractor: New CRC: \(newCRC, privacy: .private)",
            module: .interactor
        )
        
        guard newCRC == oldCRC else {
            Log("ProtectionInteractor: CRC doesn't match. Wrong words", module: .interactor)
            return .failure(.wrongWords)
        }
        
        Log("ProtectionInteractor: CRC matches. Setting Seed and Entropy", module: .interactor)
        
        mainRepository.setSeed(seed)
        mainRepository.setEntropy(entropy)
        mainRepository.saveMasterKeyEntropy(entropy)
        
        return .success(())
    }
    
    func wordsToEntropy(_ words: [String]) -> Entropy? {
        guard let (entropy, _) = mainRepository.convertWordsTo4BitPacksAndCRC(words) else {
            Log("ProtectionInteractor: Error while creating Entropy and CRC", module: .interactor, severity: .error)
            return nil
        }
        return entropy
    }
    
    func recreateSeedSaltWordsMasterKey() -> Bool {
        Log("ProtectionInteractor: Recreate Seed, Salt, Words, MasterKey", module: .interactor)
        Log("ProtectionInteractor: Creating Salt", module: .interactor)
        guard let entropy = mainRepository.entropy else {
            Log(
                "ProtectionInteractor: Error while getting Entropy - it's missing",
                module: .interactor,
                severity: .error
            )
            return false
        }
        let seed = mainRepository.createSeed(from: entropy)
        Log(
            "ProtectionInteractor: Seed: \(seed.hexEncodedString())",
            module: .interactor,
            severity: .error
        )
        Log(
            "ProtectionInteractor: Entropy: \(entropy.hexEncodedString()), Seed: \(seed.hexEncodedString())",
            module: .interactor
        )
        let groups = mainRepository.create11BitPacks(from: entropy, seed: seed)
        Log("ProtectionInteractor: 11Bit packs from Entropy and Seed: \(groups)", module: .interactor)
        
        guard let words = mainRepository.createWords(from: groups) else {
            Log("ProtectionInteractor: Error while getting Words", module: .interactor, severity: .error)
            return false
        }
        Log("ProtectionInteractor: Words: \(words)", module: .interactor)
        
        Log("ProtectionInteractor: Creating Salt", module: .interactor)
        guard let salt = mainRepository.createSalt(from: words) else {
            Log("ProtectionInteractor: Error while creating Salt", module: .interactor, severity: .error)
            return false
        }
        
        Log("ProtectionInteractor: Salt: \(salt.hexEncodedString())", module: .interactor)
        
        mainRepository.setWords(words)
        mainRepository.setSeed(seed)
        mainRepository.setSalt(salt)
        
        guard let masterPassword = mainRepository.masterPassword else {
            Log("ProtectionInteractor: Error while getting Master Password", module: .interactor, severity: .error)
            return false
        }
        
        guard let masterKey = createMasterKey(using: masterPassword, seed: seed, salt: salt) else {
            Log("ProtectionInteractor: Error while generating Master Key", module: .interactor, severity: .error)
            return false
        }
        
        mainRepository.setEmpheralMasterKey(masterKey)
        
        return true
    }
    
    func createExternalSymmetricKey(from masterKey: MasterKey, vaultID: VaultID) -> SymmetricKey? {
        guard let key = mainRepository.generateExternalKeyForVaultID(vaultID, using: masterKey.hexEncodedString()),
              let externalKeyData = Data(hexString: key)
        else {
            Log("Import Interactor - Error creating Symmetric Key")
            return nil
        }
        return mainRepository.createSymmetricKey(from: externalKeyData)
    }
}

private extension ProtectionInteractor {
    func createMasterKey(using masterPassword: MasterPassword) -> MasterKey? {
        Log("ProtectionInteractor: Creating Master Key", module: .interactor)
        Log("ProtectionInteractor: Getting Seed", module: .interactor)
        guard let seed = mainRepository.seed else {
            Log("ProtectionInteractor: Error - can't find Seed", module: .interactor, severity: .error)
            return nil
        }
        Log("ProtectionInteractor: Seed: \(seed.hexEncodedString())", module: .interactor)
        Log("ProtectionInteractor: Getting Salt", module: .interactor)
        if mainRepository.salt == nil {
            Log("ProtectionInteractor: Can't find Salt. Recreating", module: .interactor)
            createSalt()
        }
        
        guard let salt = mainRepository.salt else {
            Log("ProtectionInteractor: Error - Can't get Salt.", module: .interactor, severity: .error)
            return nil
        }
        
        Log("ProtectionInteractor: Salt: \(salt.hexEncodedString())", module: .interactor)
        
        let masterKey = createMasterKey(using: masterPassword, seed: seed, salt: salt)
        
        return masterKey
    }
    
    func createMasterKey(using masterPassword: MasterPassword, entropy: Entropy, kdfSpec: KDFSpec = .default) -> MasterKey? {
        let seed = mainRepository.createSeed(from: entropy)
        Log(
            "ProtectionInteractor: Seed: \(seed.hexEncodedString())",
            module: .interactor
        )
        Log(
            "ProtectionInteractor: Entropy: \(entropy.hexEncodedString()), Seed: \(seed.hexEncodedString())",
            module: .interactor
        )
        let groups = mainRepository.create11BitPacks(from: entropy, seed: seed)
        Log("ProtectionInteractor: 11Bit packs from Entropy and Seed: \(groups)", module: .interactor)
        
        guard let words = mainRepository.createWords(from: groups) else {
            Log("ProtectionInteractor: Error while getting Words", module: .interactor, severity: .error)
            return nil
        }
        Log("ProtectionInteractor: Words: \(words)", module: .interactor)
        
        Log("ProtectionInteractor: Creating Salt", module: .interactor)
        guard let salt = mainRepository.createSalt(from: words) else {
            Log("ProtectionInteractor: Error while creating Salt", module: .interactor, severity: .error)
            return nil
        }
        
        Log("ProtectionInteractor: Salt: \(salt.hexEncodedString())", module: .interactor)
        
        return createMasterKey(using: masterPassword, seed: seed, salt: salt, kdfSpec: kdfSpec)
    }
    
    func createMasterKey(using masterPassword: MasterPassword, seed: Seed, salt: Salt, kdfSpec: KDFSpec = .default) -> MasterKey? {
        Log(
            "ProtectionInteractor: Creating Master Key using Master Password: \(masterPassword)",
            module: .interactor
        )
        Log("ProtectionInteractor: Getting Seed", module: .interactor)
        Log("ProtectionInteractor: Seed: \(seed.hexEncodedString())", module: .interactor)
        Log("ProtectionInteractor: Getting Salt", module: .interactor)

        Log("ProtectionInteractor: Salt: \(salt.hexEncodedString())", module: .interactor)
        Log("ProtectionInteractor: Generating Master Key", module: .interactor)
        guard let masterKey = mainRepository.generateMasterKey(
            with: masterPassword,
            seed: seed,
            salt: salt,
            kdfSpec: kdfSpec
        ) else {
            Log("ProtectionInteractor: Error while generating Master Key", module: .interactor, severity: .error)
            return nil
        }
        Log("ProtectionInteractor: Master Key: \(masterKey.hexEncodedString())", module: .interactor)
        return masterKey
    }
}
