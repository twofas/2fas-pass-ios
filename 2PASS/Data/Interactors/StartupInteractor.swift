// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

public enum StartupInteractorStartResult {
    case selectVault
    case enterWords
    case enterPassword
    case login
    case main
}

public enum StartupInteractorSetWordsResult {
    case success
    case wrongWords
    case generalError
}

public protocol StartupInteracting: AnyObject {
    var canUseBiometry: Bool { get }
    var words: [String]? { get }
    var masterPassword: String? { get }
    
    var seed: Seed? { get }
    var salt: Salt? { get }
    var masterKey: MasterKey? { get }
    var entropy: Entropy? { get }
    
    var isUserSetUp: Bool { get }
    
    func getAllWords() -> [String]
    
    func initialize()
    func start() async -> StartupInteractorStartResult
    func setupEncryptionElements()
    func setMasterPassword(masterPassword: String?, enableBiometryLogin: Bool, completion: @escaping () -> Void)
    func clearAfterInit()
    func setWords(words: [String], masterPassword: MasterPassword?) -> StartupInteractorSetWordsResult
    @discardableResult
    func setEntropy(_ entropy: Entropy, masterKey: MasterKey?) -> Bool
    func wordsToEntropy(_ words: [String]) -> Entropy?
    func createVault(for vaultID: VaultID, creationDate: Date?, modificationDate: Date?) -> Bool
    func restoreVault(entropy: Entropy, masterKey: MasterKey) async -> Bool
}

extension StartupInteracting {
    
    func createVault(for vaultID: VaultID) -> Bool {
        createVault(for: vaultID, creationDate: nil, modificationDate: nil)
    }
}

final class StartupInteractor {
    private let protectionInteractor: ProtectionInteracting
    private let storageInteractor: StorageInteracting
    private let biometryInteractor: BiometryInteracting
    private let onboardingInteractor: OnboardingInteracting
    private let migrationInteractor: MigrationInteracting
    private let securityInteractor: SecurityInteracting
    
    init(
        protectionInteractor: ProtectionInteracting,
        storageInteractor: StorageInteracting,
        biometryInteractor: BiometryInteracting,
        onboardingInteractor: OnboardingInteracting,
        migrationInteractor: MigrationInteracting,
        securityInteractor: SecurityInteracting
    ) {
        self.protectionInteractor = protectionInteractor
        self.storageInteractor = storageInteractor
        self.biometryInteractor = biometryInteractor
        self.onboardingInteractor = onboardingInteractor
        self.migrationInteractor = migrationInteractor
        self.securityInteractor = securityInteractor
    }
}

extension StartupInteractor: StartupInteracting {
    var canUseBiometry: Bool {
        biometryInteractor.canUseBiometryForOnboarding
    }
    
    var words: [String]? {
        protectionInteractor.words
    }
    
    var masterPassword: String? {
        protectionInteractor.masterPassword
    }
    
    var seed: Seed? { protectionInteractor.seed }
    var salt: Salt? { protectionInteractor.salt }
    var masterKey: MasterKey? { protectionInteractor.masterKey }
    var entropy: Entropy? { protectionInteractor.entropy }
    
    var isUserSetUp: Bool {
        protectionInteractor.hasAppKey
        && protectionInteractor.hasEncryptedEntropy
        && protectionInteractor.hasEncryptionReference
        && (migrationInteractor.requiresReencryptionMigration() || protectionInteractor.hasVault)
        && onboardingInteractor.isOnboardingCompleted
    }
    
    /// Run once on app startup
    func initialize() {
        Log("StartupInteractor: Initializing", module: .interactor)
        
        migrationInteractor.migrateIfNeeded()
        
        if !protectionInteractor.hasDeviceID {
            Log(
                "StartupInteractor: No Device ID. Clearing all encryption elements and setting new Device ID",
                module: .interactor
            )
            protectionInteractor.clearApp()
            protectionInteractor.setupDeviceID()
        }
        
        if !protectionInteractor.hasAppKey {
            protectionInteractor.clearAppKeyEncryptedStorage()
            protectionInteractor.createAppKey { _ in }
        }

        if !protectionInteractor.hasBiometryKey {
            protectionInteractor.clearMasterKeyEncrypted()
        }
    }
    
    /// Run every time user is in logged out state
    @MainActor
    func start() async -> StartupInteractorStartResult {
        Log("StartupInteractor: Start", module: .interactor)
        
        if protectionInteractor.hasAppKey, protectionInteractor.verifyAppKey() == false {
            return .enterWords
        }
        
        guard !migrationInteractor.requiresReencryptionMigration() else {
            return .login
        }
        
        await storageInteractor.loadStore()
        migrationInteractor.migrateStorageIfNeeded()

        guard protectionInteractor.hasVault, onboardingInteractor.isOnboardingCompleted else {
            Log("StartupInteractor: Select Vault", module: .interactor)
            return .selectVault
        }
        
        guard protectionInteractor.hasEncryptedEntropy else {
            Log("StartupInteractor: Enter Words", module: .interactor)
            return .enterWords
        }
        
        guard protectionInteractor.hasEncryptionReference else {
            Log("StartupInteractor: No Encryption Reference", module: .interactor)
            if protectionInteractor.vaultHasTrustedItems {
                Log("StartupInteractor: Enter Password", module: .interactor)
                
                protectionInteractor.selectVault()
                
                return .enterPassword
            } else {
                storageInteractor.clear()
                Log("StartupInteractor: Set Master Password", module: .interactor)
                return .selectVault
            }
        }
        
        protectionInteractor.selectVault()
        
        if securityInteractor.isUserLoggedIn {
            return .main
        }
        
        return .login
    }
    
    func setupEncryptionElements() {
        Log("StartupInteractor: Setup Entryption Elements", module: .interactor)
        protectionInteractor.generateEntropy()
        protectionInteractor.createSeed()
        protectionInteractor.createSalt()
    }
    
    func setMasterPassword(masterPassword: String?, enableBiometryLogin: Bool, completion: @escaping () -> Void) {
        Log("StartupInteractor: Set Master Password. Enable biometry: \(enableBiometryLogin)", module: .interactor)
        protectionInteractor.restoreEntropy()
        protectionInteractor.createSeed()
        protectionInteractor.createSalt()
        if let masterPassword {
            protectionInteractor.setMasterKey(for: masterPassword)
        }
        biometryInteractor.setBiometryEnabled(enableBiometryLogin) { [weak self] result in
            self?.protectionInteractor.saveEncryptionReference()
            self?.protectionInteractor.createNewVault(with: .init())
            self?.protectionInteractor.selectVault()
            self?.protectionInteractor.setupKeys()
            self?.protectionInteractor.saveEntropy()
            self?.storageInteractor.initialize {
                completion()
            }
        }
    }
    
    func setWords(words: [String], masterPassword: MasterPassword?) -> StartupInteractorSetWordsResult {
        Log("StartupInteractor: Set Words and Master Password", module: .interactor)
        switch protectionInteractor.setWords(words, masterPassword: masterPassword) {
        case .success: return .success
        case .failure(let error):
            switch error {
            case .wrongWords: return .wrongWords
            case .general: return .generalError
            }
        }
    }
    
    @discardableResult
    func setEntropy(_ entropy: Entropy, masterKey: MasterKey?) -> Bool {
        Log("StartupInteractor: Set Entropy and Master Key", module: .interactor)
        return protectionInteractor.setEntropy(entropy, masterKey: masterKey)
    }
    
    func wordsToEntropy(_ words: [String]) -> Entropy? {
        protectionInteractor.wordsToEntropy(words)
    }
    
    func clearAfterInit() {
        Log("StartupInteractor: Clear after init", module: .interactor)
        protectionInteractor.clearAfterInit()
    }
    
    func getAllWords() -> [String] {
        protectionInteractor.getAllWords()
    }
    
    func createVault(for vaultID: VaultID, creationDate: Date?, modificationDate: Date?) -> Bool {
        protectionInteractor.saveEncryptionReference()
        protectionInteractor.createNewVault(with: vaultID, creationDate: creationDate, modificationDate: modificationDate)
        protectionInteractor.selectVault()
        protectionInteractor.setupKeys()
        protectionInteractor.saveEntropy()
        storageInteractor.initialize(completion: {})
        
        return true
    }
    
    @MainActor
    func restoreVault(entropy: Entropy, masterKey: MasterKey) async -> Bool {
        guard protectionInteractor.setEntropy(entropy, masterKey: masterKey) else {
            return false
        }
 
        if migrationInteractor.requiresReencryptionMigration() {
            guard await migrationInteractor.loadStoreWithReencryptionMigration() else {
                return false
            }
        } else {
            await storageInteractor.loadStore()
        }
        migrationInteractor.migrateStorageIfNeeded()

        guard protectionInteractor.verifyMasterKeyForVault(masterKey) else {
            return false
        }
                
        protectionInteractor.clearAppKeyStorage()
        
        await withCheckedContinuation { continuation in
            biometryInteractor.setBiometryEnabled(false) { _ in
                continuation.resume()
            }
        }
        
        let createAppKeySuccess = await withCheckedContinuation { continuatioon in
            protectionInteractor.createAppKey { result in
                continuatioon.resume(returning: result)
            }
        }
        
        guard createAppKeySuccess else {
            return false
        }
        
        protectionInteractor.setupDeviceID()
        protectionInteractor.saveEncryptionReference()
        protectionInteractor.selectVault()
        protectionInteractor.setupKeys()
        protectionInteractor.updateExistingVault()
        protectionInteractor.saveEntropy()
        
        await withCheckedContinuation { continuation in
            storageInteractor.initialize {
                continuation.resume()
            }
        }

        protectionInteractor.clearAfterInit()

        return true
    }
}
