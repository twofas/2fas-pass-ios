// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common
import CommonCrypto

public enum LoginMasterPasswordResult {
    case success
    case invalidPassword
    case invalidPasswordAppLocked
    case appLocked
}

public enum LoginBiometryResult {
    case success
    case failure
    case unavailable
    case appLocked
}

public protocol LoginInteracting: AnyObject {
    var canUseBiometryToLogin: Bool { get }
    var prefillMasterPassword: String? { get }
    var biometryType: BiometryType { get }
    
    var shouldRequestForBiometryToLogin: Bool { get }
    func finishRequestForBiometryToLogin()
    
    var lockLogin: (() -> Void)? { get set }
    var unlockLogin: (() -> Void)? { get set }
    var appLockRemainingSeconds: Int? { get }
    var isAppLocked: Bool { get }

    func loginUsingMasterPassword(
        _ masterPassword: MasterPassword,
        completion: @escaping (LoginMasterPasswordResult) -> Void
    )
    
    func loginUsingBiometry(
        reason: String,
        completion: @escaping (LoginBiometryResult) -> Void
    )
    
    func verifyMasterPassword(
        _ masterPassword: MasterPassword,
        completion: @escaping (LoginMasterPasswordResult) -> Void
    )
    
    func verifyMasterPasswordUsingVault(
        _ masterPassword: MasterPassword,
        completion: @escaping (LoginMasterPasswordResult) -> Void
    )
    
    func verifyUsingBiometry(
        reason: String,
        completion: @escaping (LoginBiometryResult) -> Void
    )
    
    func saveMasterPassword(_ masterPassword: MasterPassword)
    func setMasterKey(for masterPassword: MasterPassword)
    func clearMasterKey()
    func saveEncryptionReference()
    func resetApp()
    func verifyMasterPassword(
        using masterPassword: MasterPassword,
        entropy: Entropy,
        seedHashHex: String,
        reference: String,
        vaultID: VaultID,
        kdfSpec: KDFSpec?,
        completion: @escaping (MasterKey?) -> Void
    )
    
    func verifyMasterKey(
        using masterKey: MasterKey,
        entropy: Entropy,
        seedHashHex: String,
        reference: String,
        vaultID: VaultID,
        completion: @escaping (MasterKey?) -> Void
    )

    func loginUsingMasterKey(_ masterKey: MasterKey) async -> Bool
}

final class LoginInteractor {
    private let mainRepository: MainRepository
    private let protectionInteractor: ProtectionInteracting
    private let securityInteractor: SecurityInteracting
    private let storageInteractor: StorageInteracting
    private let biometryInteractor: BiometryInteracting
    private let notificationCenter: NotificationCenter
    
    init(
        mainRepository: MainRepository,
        protectionInteractor: ProtectionInteracting,
        securityInteractor: SecurityInteracting,
        storageInteractor: StorageInteracting,
        biometryInteractor: BiometryInteracting
    ) {
        self.mainRepository = mainRepository
        self.protectionInteractor = protectionInteractor
        self.securityInteractor = securityInteractor
        self.storageInteractor = storageInteractor
        self.biometryInteractor = biometryInteractor
        self.notificationCenter = .default
    }
}

extension LoginInteractor: LoginInteracting {
    var prefillMasterPassword: String? {
        mainRepository.masterPassword
    }
    
    var shouldRequestForBiometryToLogin: Bool {
        biometryInteractor.isBiometryAvailable && biometryInteractor.isBiometryEnabled == false && mainRepository.requestedForBiometryToLogin == false && mainRepository.empheralMasterKey != nil
    }
    
    func finishRequestForBiometryToLogin() {
        mainRepository.setRequestedForBiometryToLogin(true)
    }
    
    var canUseBiometryToLogin: Bool {
        biometryInteractor.canUseBiometryForLogin && !securityInteractor.isAppLocked
    }
    
    var biometryType: BiometryType {
        biometryInteractor.biometryType
    }
    
    var appLockRemainingSeconds: Int? {
        securityInteractor.appLockRemainingSeconds
    }
    
    var isAppLocked: Bool {
        securityInteractor.isAppLocked
    }
    
    var lockLogin: (() -> Void)? {
        get {
            securityInteractor.lockLogin
        }
        set {
            securityInteractor.unlockLogin = newValue
        }
    }
    
    var unlockLogin: (() -> Void)? {
        get {
            securityInteractor.unlockLogin
        }
        set {
            securityInteractor.unlockLogin = newValue
        }
    }
    
    func loginUsingMasterPassword(
        _ masterPassword: MasterPassword,
        completion: @escaping (LoginMasterPasswordResult) -> Void
    ) {
        useMasterPassword(masterPassword, login: true, completion: completion)
    }
    
    func loginUsingBiometry(reason: String, completion: @escaping (LoginBiometryResult) -> Void) {
        useBiometry(reason: reason, login: true, completion: completion)
    }
    
    func verifyMasterPassword(
        _ masterPassword: MasterPassword,
        completion: @escaping (LoginMasterPasswordResult) -> Void
    ) {
        useMasterPassword(masterPassword, login: false, completion: completion)
    }
    
    func verifyUsingBiometry(
        reason: String,
        completion: @escaping (LoginBiometryResult) -> Void
    ) {
        useBiometry(reason: reason, login: false, completion: completion)
    }
    
    func verifyMasterPasswordUsingVault(
        _ masterPassword: MasterPassword,
        completion: @escaping (LoginMasterPasswordResult) -> Void
    ) {
        Log("LoginInteractor: veryfing using Master Password and Vault", module: .interactor)
        guard !securityInteractor.isAppLocked else {
            Log("LoginInteractor: App Locked", module: .interactor)
            completion(.appLocked)
            return
        }
        guard let entropy = protectionInteractor.entropy else {
            Log("LoginInteractor: No entropy!", module: .interactor, severity: .error)
            completion(.invalidPassword)
            return
        }
        guard let masterKey = protectionInteractor.masterKey(
            from: masterPassword,
            entropy: entropy,
            kdfSpec: .default
        ) else {
            Log("LoginInteractor: Can't create Master Key", module: .interactor, severity: .error)
            completion(.invalidPassword)
            return
        }
        guard let vault = mainRepository.listEncryptedVaults().first else {
            Log("LoginInteractor: Can't get Vault", module: .interactor, severity: .error)
            completion(.invalidPassword)
            return
        }
        guard let trustedContent = mainRepository
            .listEncryptedItems(in: vault.vaultID)
            .filter({ $0.protectionLevel != .topSecret }).first?.content else {
            Log("LoginInteractor: Can't get Trusted Password", module: .interactor, severity: .error)
            completion(.invalidPassword)
            return
        }
        guard let trustedKeyString = mainRepository
            .generateTrustedKeyForVaultID(vault.vaultID, using: masterKey.hexEncodedString()),
              let trustedKey = Data(hexString: trustedKeyString) else {
            Log("LoginInteractor: Can't generate Trusted Key", module: .interactor, severity: .error)
            completion(.invalidPassword)
            return
            
        }
        if mainRepository.decrypt(
            trustedContent,
            key: mainRepository.createSymmetricKey(from: trustedKey)
        ) != nil {
            securityInteractor.markCorrectLogin()
            userLoggedIn(using: masterPassword) { [weak self] in
                completion(.success)
                self?.protectionInteractor.clearAfterInit()
            }
            return
        }
        securityInteractor.markWrongPassword()
        completion(.invalidPassword)
    }
    
    func verifyMasterPassword(
        using masterPassword: MasterPassword,
        entropy: Entropy,
        seedHashHex: String,
        reference: String,
        vaultID: VaultID,
        kdfSpec: KDFSpec?,
        completion: @escaping (MasterKey?) -> Void
    ) {
        guard let kdfSpec else {
            Log(
                "LoginInteractor: Can't gather KDFSpec for Master Password validation",
                module: .interactor,
                severity: .error
            )
            completion(nil)
            return
        }
        guard let masterKey = protectionInteractor.masterKey(
            from: masterPassword,
            entropy: entropy,
            kdfSpec: kdfSpec
        ) else {
            Log(
                "LoginInteractor: Can't create Master Key while veryfing Master Password",
                module: .interactor,
                severity: .error
            )
            completion(nil)
            return
        }
        
        verifyMasterKey(
            using: masterKey,
            entropy: entropy,
            seedHashHex: seedHashHex,
            reference: reference,
            vaultID: vaultID,
            completion: completion
        )
    }
    
    func verifyMasterKey(
        using masterKey: MasterKey,
        entropy: Entropy,
        seedHashHex: String,
        reference: String,
        vaultID: VaultID,
        completion: @escaping (MasterKey?) -> Void
    ) {
        guard let key = protectionInteractor.createExternalSymmetricKey(from: masterKey, vaultID: vaultID) else {
            completion(nil)
            return
        }
        guard let data = Data(base64Encoded: reference),
              let decryptedValue = mainRepository.decrypt(data, key: key),
              let uuidString = String(data: decryptedValue, encoding: .utf8),
              let uuid = UUID(uuidString: uuidString), uuid == vaultID else {
            completion(nil)
            return
        }
        
        let seed = mainRepository.createSeed(from: entropy)
        guard let comparisionSeedHash = mainRepository.generateExchangeSeedHash(vaultID, using: seed),
              let externalSeedHashHexString = Data(base64Encoded: seedHashHex)?.hexEncodedString()
        else {
            Log("LoginInteractor: Can't create SeedHash for validation", module: .interactor)
            completion(nil)
            return
        }
        
        guard comparisionSeedHash == externalSeedHashHexString else {
            Log("LoginInteractor: SeedHashHex do not match", module: .interactor)
            completion(nil)
            return
        }
        completion(masterKey)
    }

    func loginUsingMasterKey(_ masterKey: MasterKey) async -> Bool {
        Log("LoginInteractor: login using Master Key", module: .interactor)
        guard !securityInteractor.isAppLocked else {
            Log("LoginInteractor: App Locked", module: .interactor)
            return false
        }

        guard protectionInteractor.verifyMasterKey(masterKey) else {
            Log("LoginInteractor: Master Key verification failed", module: .interactor, severity: .error)
            securityInteractor.markWrongPassword()
            return false
        }

        securityInteractor.markCorrectLogin()
        await withCheckedContinuation { continuation in
            userLoggedInUsingMasterKey(masterKey) { [weak self] in
                self?.protectionInteractor.clearAfterInit()
                continuation.resume()
            }
        }
        return true
    }

    func saveMasterPassword(_ masterPassword: MasterPassword) {
        protectionInteractor.setMasterPassword(masterPassword)
    }
    
    func saveEncryptionReference() {
        protectionInteractor.saveEncryptionReference()
    }
    
    func resetApp() {
        protectionInteractor.clearApp()
    }
    
    func setMasterKey(for masterPassword: MasterPassword) {
        protectionInteractor.restoreEntropy()
        protectionInteractor.setMasterKey(for: masterPassword)
    }
    
    func clearMasterKey() {
        protectionInteractor.clearEntropy()
        protectionInteractor.clearMasterKey()
    }
}

private extension LoginInteractor {
    func useMasterPassword(
        _ masterPassword: MasterPassword,
        login: Bool,
        completion: @escaping (LoginMasterPasswordResult) -> Void
    ) {
        Log("LoginInteractor: login using Master Password", module: .interactor)
        guard !securityInteractor.isAppLocked else {
            Log("LoginInteractor: App Locked", module: .interactor)
            completion(.appLocked)
            return
        }
        if protectionInteractor.verifyMasterPassword(masterPassword) {
            Log("LoginInteractor: Master Password verified succesfully", module: .interactor)
            securityInteractor.markCorrectLogin()
            if login {
                userLoggedIn(using: masterPassword) { [weak self] in
                    completion(.success)
                    self?.protectionInteractor.clearAfterInit()
                }
            } else {
                completion(.success)
            }
        } else {
            Log("LoginInteractor: Master Password login failed - invalid password", module: .interactor)
            securityInteractor.markWrongPassword()
            if securityInteractor.isAppLocked {
                Log("LoginInteractor: App is locked after last login", module: .interactor)
                completion(.invalidPasswordAppLocked)
            } else {
                completion(.invalidPassword)
            }
        }
    }
    
    func useBiometry(reason: String, login: Bool, completion: @escaping (LoginBiometryResult) -> Void) {
        Log("LoginInteractor: Login using Biometry", module: .interactor)
        guard !securityInteractor.isAppLocked else {
            Log("LoginInteractor: App is locked", module: .interactor)
            completion(.appLocked)
            return
        }
        biometryInteractor.loginUsingBiometry(reason: reason) { [weak self] result in
            switch result {
            case .success(let masterKey):
                self?.securityInteractor.markCorrectLogin()
                if login {
                    self?.userLoggedInUsingMasterKey(masterKey, completion: { [weak self] in
                        completion(.success)
                        self?.protectionInteractor.clearAfterInit()
                    })
                } else {
                    self?.protectionInteractor.clearAfterInit()
                    completion(.success)
                }
            case .failure:
                Log("LoginInteractor: Biometry login failed", module: .interactor)
                completion(.failure)
            case .failureBiometryLockedOut, .failureWrongFingerprint, .biometryLockedOut,
                    .notEnabled, .inProgress, .cancelled:
                Log("LoginInteractor: Biometry login unavailable", module: .interactor)
                completion(.unavailable)
            }
        }
    }
    
    func userLoggedIn(using masterPassword: String, completion: @escaping () -> Void) {
        Log("LoginInteractor: User logged in using Master Password", module: .interactor)
        protectionInteractor.setMasterKey(for: masterPassword)
        protectionInteractor.setupKeys()
        storageInteractor.initialize { [weak self] in
            completion()
            self?.notificationCenter.post(name: .userLoggedIn, object: nil)
        }
    }
    
    func userLoggedInUsingMasterKey(_ masterKey: MasterKey, completion: @escaping () -> Void) {
        Log("LoginInteractor: login using Biometry", module: .interactor)
        protectionInteractor.restoreEntropy()
        protectionInteractor.createSeed()
        protectionInteractor.createSalt()
        protectionInteractor.setMasterKey(masterKey)
        protectionInteractor.setupKeys()
        storageInteractor.initialize { [weak self] in
            completion()
            self?.notificationCenter.post(name: .userLoggedIn, object: nil)
        }
    }
}
