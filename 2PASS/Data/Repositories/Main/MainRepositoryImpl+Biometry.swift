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
        Log("Authenticating using enhanced biometric security", module: .mainRepository)
        
        // Check for security lockout first
        if BiometricSecurity.isLockedOut() {
            Log("Biometric authentication is locked out due to multiple failed attempts", module: .mainRepository)
            DispatchQueue.main.async {
                completion(.failure)
            }
            return
        }
        
        // Use enhanced biometric security
        BiometricSecurity.authenticateWithEnhancedSecurity(
            reason: reason,
            context: authContext
        ) { [weak self] result in
            guard let self else { return }
            
            switch result {
            case .success(let domainState):
                Log("Enhanced BioAuthSuccess", module: .mainRepository)
                BiometricSecurity.resetAuthenticationState()
                completion(.success(fingerprint: domainState))
                
            case .cancelled:
                Log("Enhanced BioAuthCancelled", module: .mainRepository)
                completion(.cancelled)
                
            case .fallbackRequested:
                Log("Biometric fallback requested", module: .mainRepository)
                self.handleBiometricFallback(completion: completion)
                
            case .timeout:
                Log("Biometric authentication timed out", module: .mainRepository)
                BiometricSecurity.recordFailedAttempt()
                completion(.failure)
                
            case .securityCompromised:
                Log("Biometric security compromised - blocking authentication", module: .mainRepository, severity: .error)
                BiometricSecurity.recordFailedAttempt()
                completion(.failure)
                
            case .failure(let error):
                Log("Enhanced biometric authentication failed: \(error)", module: .mainRepository)
                BiometricSecurity.recordFailedAttempt()
                completion(.failure)
            }
        }
    }
    
    private func handleBiometricFallback(completion: @escaping (BiometricAuthResult) -> Void) {
        Log("Handling biometric fallback authentication", module: .mainRepository)
        
        BiometricSecurity.handleSecureFallback { fallbackResult in
            switch fallbackResult {
            case .success:
                Log("Fallback authentication successful", module: .mainRepository)
                BiometricSecurity.resetAuthenticationState()
                // Create a synthetic domain state for fallback success
                let fallbackState = Data("fallback_auth_success".utf8)
                completion(.success(fingerprint: fallbackState))
                
            case .cancelled:
                Log("Fallback authentication cancelled", module: .mainRepository)
                completion(.cancelled)
                
            case .failed, .unavailable:
                Log("Fallback authentication failed", module: .mainRepository)
                BiometricSecurity.recordFailedAttempt()
                completion(.failure)
            }
        }
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
