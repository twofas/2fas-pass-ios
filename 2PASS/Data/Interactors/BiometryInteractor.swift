// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

public enum BiometryInteractorLoginResult {
    case success(MasterKey)
    case failure
    case failureBiometryLockedOut
    case failureWrongFingerprint
    case biometryLockedOut
    case notEnabled
    case inProgress
    case cancelled
}

public protocol BiometryInteracting: AnyObject {
    var isBiometryLocked: Bool { get }
    var canUseBiometryForLogin: Bool { get }
    var canUseBiometryForOnboarding: Bool { get }
    var isBiometryEnabled: Bool { get }
    var isBiometryAvailable: Bool { get }
    var isBiometryLockedOut: Bool { get }
    var biometryType: BiometryType { get }
    
    func setBiometryEnabled(_ enabled: Bool, completion: @escaping (Bool) -> Void)
    func loginUsingBiometry(reason: String, result: @escaping (BiometryInteractorLoginResult) -> Void)
}

final class BiometryInteractor {
    private enum BiometryAuthResult {
        case success
        case failure
        case failureWrongFingerprint
        case failureBiometryLockedOut
        case inProgress
        case cancelled
    }
    
    private var isAuthenticatingUsingBiometric = false
    
    private let biometryMaxAttempts = 3
    
    private let mainRepository: MainRepository
    
    init(mainRepository: MainRepository) {
        self.mainRepository = mainRepository
    }
}

extension BiometryInteractor: BiometryInteracting {
    
    var isBiometryLocked: Bool {
        mainRepository.incorrectBiometryCountAttemp >= biometryMaxAttempts
    }
    
    var canUseBiometryForLogin: Bool {
        isBiometryEnabled && isBiometryAvailable && !isBiometryLockedOut && !isBiometryLocked
    }
    
    var canUseBiometryForOnboarding: Bool {
        isBiometryAvailable && !isBiometryLockedOut
    }
    
    var isBiometryEnabled: Bool {
        mainRepository.isBiometryEnabled
    }
    
    var isBiometryAvailable: Bool {
        mainRepository.isBiometryAvailable
    }
    
    var isBiometryLockedOut: Bool {
        mainRepository.isBiometryLockedOut
    }
    
    var biometryType: BiometryType {
        mainRepository.biometryType
    }
    
    func setBiometryEnabled(_ enabled: Bool, completion: @escaping (Bool) -> Void) {
        Log("BiometryInteractor: Set Biometry enabled: \(enabled)", module: .interactor)
        
        guard enabled else {
            disableBiometry()
            completion(false)
            return
        }
        
        guard let masterKey = mainRepository.empheralMasterKey else {
            Log("BiometryInteractor: No Master Key available", module: .interactor, severity: .error)
            completion(false)
            return
        }
        
        Log("BiometryInteractor: Obtaining Biometry Key", module: .interactor)
        
        mainRepository.blockAppLocking()
        getBiometryKey { [weak self] bioKey in
            self?.mainRepository.unblockAppLocking()
            guard let bioKey = bioKey else {
                Log("BiometryInteractor: No Biometry Key available", module: .interactor, severity: .error)
                completion(false)
                return
            }
            
            Log("BiometryInteractor: Creating Symmetric Key from Secure Enclave", module: .interactor)
            
            guard let symm = self?.mainRepository.createSymmetricKeyFromSecureEnclave(from: bioKey) else {
                Log(
                    "BiometryInteractor: Can't create Symmetric Key from Biometry Key",
                    module: .interactor,
                    severity: .error
                )
                completion(false)
                return
            }
            
            Log("BiometryInteractor: Encrypting")
            
            guard let encrypted = self?.mainRepository.encrypt(masterKey, key: symm) else {
                Log("BiometryInteractor: Can't encrypt Biometry Key", module: .interactor, severity: .error)
                completion(false)
                return
            }
            
            Log("BiometryInteractor: Saving encrypted Master Key", module: .interactor)
            
            self?.mainRepository.saveMasterKey(encrypted)
            self?.mainRepository.reloadAuthContext()
            completion(true)
        }
    }
    
    func loginUsingBiometry(reason: String, result: @escaping (BiometryInteractorLoginResult) -> Void) {
        Log("BiometryInteractor: Login using Biometry", module: .interactor)
        mainRepository.reloadAuthContext()
        
        Log("BiometryInteractor: Logging using Biometry", module: .interactor)
        guard isBiometryEnabled else {
            Log("BiometryInteractor: Not Enabled!", module: .interactor)
            result(.notEnabled)
            return
        }
        guard !isBiometryLockedOut && !isBiometryLocked else {
            Log("BiometryInteractor: Login locked out!", module: .interactor)
            result(.biometryLockedOut)
            return
        }
        
        authenticateUsingBiometry(reason: reason) { [weak self] authResult in
            switch authResult {
            case .success:
                Log("BiometryInteractor: Login success", module: .interactor)
                self?.markSuccessfulAuth()
                guard let masterKeyEncrypted = self?.mainRepository.decryptStoredMasterKey() else {
                    Log("BiometryInteractor: Can't get encrypted Master Key!", module: .interactor)
                    self?.disableBiometry()
                    result(.failure)
                    return
                }
                self?.getBiometryKey(completion: { [weak self] bioKey in
                    guard let bioKey else {
                        Log(
                            "BiometryInteractor: Can't get Biometry Key!",
                            module: .interactor,
                            severity: .error
                        )
                        self?.disableBiometry()
                        result(.failure)
                        return
                    }
                    guard let symmKey = self?.mainRepository.createSymmetricKeyFromSecureEnclave(from: bioKey) else {
                        Log(
                            "BiometryInteractor: Can't create Symmetric Key from Biometry Key!",
                            module: .interactor,
                            severity: .error
                        )
                        self?.disableBiometry()
                        result(.failure)
                        return
                    }
                    guard let masterKey = self?.mainRepository.decrypt(masterKeyEncrypted, key: symmKey) else {
                        Log(
                            "BiometryInteractor: Can't decrypt Master Key using Biometry Key!",
                            module: .interactor,
                            severity: .error
                        )
                        self?.disableBiometry()
                        result(.failure)
                        return
                    }
                    result(.success(masterKey))
                    Log("BiometryInteractor: User logged in successfuly", module: .interactor)
                })
            case .failure:
                Log("BiometryInteractor: Login failure", module: .interactor)
                self?.markFailedAuth()
                result(.failure)
            case .failureWrongFingerprint:
                Log("BiometryInteractor: Login failure - wrong fingerprint", module: .interactor)
                result(.failureWrongFingerprint)
            case .failureBiometryLockedOut:
                Log("BiometryInteractor: Login failure - Biometry locked out", module: .interactor)
                self?.markFailedAuth()
                result(.failureBiometryLockedOut)
            case .inProgress:
                Log("BiometryInteractor: Login failure - Biometry locked out", module: .interactor)
                result(.inProgress)
            case .cancelled:
                Log("BiometryInteractor: Login failure - Biometry cancelled", module: .interactor)
                result(.cancelled)
            }
        }
    }
}

private extension BiometryInteractor {
    func getBiometryKey(completion: @escaping (BiometryKey?) -> Void) {
        Log("BiometryInteractor: Checking for Biometry Key", module: .interactor)
        
        if let bioKey = mainRepository.biometryKey {
            Log("BiometryInteractor: Biometry Key found", module: .interactor)
            completion(bioKey)
            return
        }
        
        Log("BiometryInteractor: Biometry Key not found - creating", module: .interactor)
        
        guard let secControl = mainRepository.createSecureEnclaveAccessControl(needAuth: true) else {
            Log(
                "BiometryInteractor: Error while creating Secure Enclave Access Control",
                module: .interactor,
                severity: .error
            )
            completion(nil)
            return
        }
        
        Log("BiometryInteractor: Creating Secure Enclave Private Key", module: .interactor)
        
        mainRepository.createSecureEnclavePrivateKey(accessControl: secControl) { [weak self] data in
            guard let data else {
                Log(
                    "BiometryInteractor: Error while creating Secure Enclave Private Key",
                    module: .interactor,
                    severity: .error
                )
                completion(nil)
                return
            }
            
            Log("BiometryInteractor: Saving Biometry Key", module: .interactor)
            
            self?.mainRepository.saveBiometryKey(data)
            completion(data)
        }
    }
    
    func markSuccessfulAuth() {
        Log("BiometryInteractor: Mark successful authentication", module: .interactor)
        mainRepository.clearIncorrectBiometryCountAttempt()
    }
    
    func markFailedAuth() {
        Log("BiometryInteractor: Mark authentication failure", module: .interactor)
        mainRepository.setIncorrectBiometryCountAttempt(mainRepository.incorrectBiometryCountAttemp + 1)
    }
    
    func disableBiometry() {
        Log("BiometryInteractor: Disabling Biometry", module: .interactor)
        mainRepository.disableBiometry()
        mainRepository.reloadAuthContext()
    }
    
    private func authenticateUsingBiometry(reason: String, result: @escaping (BiometryAuthResult) -> Void) {
        guard !isAuthenticatingUsingBiometric else {
            result(.inProgress)
            return
        }
        isAuthenticatingUsingBiometric = true
        guard !mainRepository.isBiometryLockedOut else {
            result(.failureBiometryLockedOut)
            return
        }
        
        mainRepository.authenticateUsingBiometry(reason: reason) { [weak self] authResult in
            self?.isAuthenticatingUsingBiometric = false
            guard self?.mainRepository.isAppInBackground == false else { return }
            
            switch authResult {
            case .success(let fingerprint):
                if let fingerprint {
                    if let currentFingerprint = self?.mainRepository.biometryFingerpring {
                        if fingerprint == currentFingerprint {
                            result(.success)
                        } else {
                            self?.disableBiometry()
                            result(.failureWrongFingerprint)
                        }
                    } else {
                        self?.mainRepository.saveBiometryFingerprint(fingerprint)
                        result(.success)
                    }
                } else {
                    self?.mainRepository.clearBiometryFingerpring()
                    result(.success)
                }
            case .failure:
                if self?.isBiometryLocked == true {
                    result(.failureBiometryLockedOut)
                    return
                }
                result(.failure)
                return
            case .cancelled:
                result(.cancelled)
                return
            }
        }
    }
}
