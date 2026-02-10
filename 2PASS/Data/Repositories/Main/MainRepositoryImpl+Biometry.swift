// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common
import LocalAuthentication

extension MainRepositoryImpl {
    var isBiometryAvailable: Bool {
        var error: NSError?
        
        let avail = authContext.canEvaluatePolicy(LAPolicy.deviceOwnerAuthenticationWithBiometrics, error: &error)
        
        if let err = error {
            Log("isAvailable - can't use bio authenticating: \(err.localizedDescription)", module: .mainRepository)
        }
        
        return avail
    }
    
    var biometryType: BiometryType {
        guard isBiometryAvailable else { return .missing }
        if authContext.biometryType == .touchID {
            return .touchID
        } else if authContext.biometryType == .faceID {
            return .faceID
        }
        return .missing
    }
    
    var isBiometryEnabled: Bool {
        biometryKey != nil && isMasterKeyStored
    }
    
    func disableBiometry() {
        clearMasterKey()
        clearBiometryKey()
        clearBiometryFingerpring()
        clearIncorrectBiometryCountAttempt()
    }
    
    func reloadAuthContext() {
        Log("Reloading LAContext", module: .mainRepository)
        authContext = LAContext()
        authContext.touchIDAuthenticationAllowableReuseDuration = 0.5
    }
    
    var isBiometryLockedOut: Bool {
        var error: NSError?
        _ = authContext.canEvaluatePolicy(LAPolicy.deviceOwnerAuthenticationWithBiometrics, error: &error)
        guard let err = error else { return false }
        return err.code == LAError.biometryLockout.rawValue
    }
    
    func authenticateUsingBiometry(
        reason: String,
        completion: @escaping (BiometricAuthResult) -> Void
    ) {
        var error: NSError?
        Log("Authenticating using bio")
        
        guard authContext.canEvaluatePolicy(LAPolicy.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            if let err = error {
                Log("Error - can't use bio authenticating: \(err.localizedDescription)", module: .mainRepository)
            }
            
            DispatchQueue.main.async {
                completion(.failure)
            }
            
            return
        }
        
        authContext.evaluatePolicy(
            LAPolicy.deviceOwnerAuthenticationWithBiometrics,
            localizedReason: reason,
            reply: { [weak self] (success: Bool, evalPolicyError: Error?) -> Void in
                
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    
                    if success {
                        let newFingerprint = self.authContext.evaluatedPolicyDomainState
                        
                        Log("BioAuthSuccess", module: .mainRepository)
                        completion(.success(fingerprint: newFingerprint))
                    } else if let code = (evalPolicyError as? LAError)?.code,
                              code == LAError.userCancel
                                || code == LAError.appCancel
                                || code == LAError.systemCancel
                                || code == LAError.userFallback
                                || code == LAError.notInteractive {
                        Log("BioAuthCancelled", module: .mainRepository)
                        completion(.cancelled)
                    } else {
                        guard let err = evalPolicyError as NSError? else {
                            assertionFailure("Unsupported conversion")
                            return
                        }
                        Log("Error while authenticating - \(err.localizedDescription)", module: .mainRepository)
                        
                        completion(.failure)
                    }
                }
            })
    }
    
    var biometryFingerpring: Data? {
        keychainDataSource.biometryFingerpring
    }
    
    func saveBiometryFingerprint(_ data: Data) {
        keychainDataSource.saveBiometryFingerprint(data)
    }
    
    func clearBiometryFingerpring() {
        keychainDataSource.clearBiometryFingerpring()
    }
    
    var requestedForBiometryToLogin: Bool {
        userDefaultsDataSource.requestedForBiometryToLogin
    }
    
    func setRequestedForBiometryToLogin(_ requested: Bool) {
        userDefaultsDataSource.setRequestedForBiometryToLogin(requested)
    }
}
