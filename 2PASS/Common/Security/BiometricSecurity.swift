// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import LocalAuthentication
import Security

/// Enhanced biometric authentication security for 2FAS Pass
public final class BiometricSecurity {
    
    // MARK: - Security Constants
    
    private static let maxFailedAttempts = 3
    private static let lockoutDurationMinutes = 5
    private static let fallbackTimeoutSeconds = 30.0
    
    // MARK: - Enhanced Biometric Authentication
    
    /// Validates biometric authentication with enhanced security measures
    /// - Parameters:
    ///   - reason: Reason for authentication
    ///   - context: Optional LAContext to use
    ///   - completion: Completion handler with enhanced result
    public static func authenticateWithEnhancedSecurity(
        reason: String,
        context: LAContext? = nil,
        completion: @escaping (BiometricSecurityResult) -> Void
    ) {
        let authContext = context ?? LAContext()
        
        // Set security configuration
        configureSecureContext(authContext)
        
        // Check if biometric is available and not compromised
        guard validateBiometricSecurity(authContext) else {
            completion(.securityCompromised)
            return
        }
        
        // Perform authentication with fallback protection
        performSecureAuthentication(
            context: authContext,
            reason: reason,
            completion: completion
        )
    }
    
    private static func configureSecureContext(_ context: LAContext) {
        // Set strict reuse duration
        context.touchIDAuthenticationAllowableReuseDuration = 0
        
        // Set localized fallback title to discourage fallback
        context.localizedFallbackTitle = ""
        
        // Set cancel title
        context.localizedCancelTitle = "Cancel"
    }
    
    private static func validateBiometricSecurity(_ context: LAContext) -> Bool {
        var error: NSError?
        
        // Check basic availability
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            if let error = error {
                NSLog("BiometricSecurity: Biometric not available - %@", error.localizedDescription)
            }
            return false
        }
        
        // Check for biometric lockout
        if let error = error, error.code == LAError.biometryLockout.rawValue {
            NSLog("BiometricSecurity: Biometric locked out")
            return false
        }
        
        // Validate domain state integrity
        if let domainState = context.evaluatedPolicyDomainState,
           !validateDomainStateIntegrity(domainState) {
            NSLog("BiometricSecurity: Domain state integrity check failed")
            return false
        }
        
        return true
    }
    
    private static func validateDomainStateIntegrity(_ domainState: Data) -> Bool {
        // Validate domain state hasn't been tampered with
        // This is a placeholder for more sophisticated checks
        return domainState.count > 0 && domainState.count <= 1024
    }
    
    private static func performSecureAuthentication(
        context: LAContext,
        reason: String,
        completion: @escaping (BiometricSecurityResult) -> Void
    ) {
        // Set up timeout protection
        var hasCompleted = false
        let timeoutTimer = Timer.scheduledTimer(withTimeInterval: fallbackTimeoutSeconds, repeats: false) { _ in
            if !hasCompleted {
                hasCompleted = true
                completion(.timeout)
            }
        }
        
        context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: reason
        ) { success, error in
            DispatchQueue.main.async {
                timeoutTimer.invalidate()
                
                guard !hasCompleted else { return }
                hasCompleted = true
                
                if success {
                    // Validate post-authentication security
                    if let newDomainState = context.evaluatedPolicyDomainState,
                       validatePostAuthenticationSecurity(newDomainState) {
                        completion(.success(domainState: newDomainState))
                    } else {
                        completion(.securityCompromised)
                    }
                } else {
                    completion(handleAuthenticationError(error))
                }
            }
        }
    }
    
    private static func validatePostAuthenticationSecurity(_ domainState: Data) -> Bool {
        // Additional post-authentication security checks
        return validateDomainStateIntegrity(domainState)
    }
    
    private static func handleAuthenticationError(_ error: Error?) -> BiometricSecurityResult {
        guard let laError = error as? LAError else {
            return .failure(.unknown)
        }
        
        switch laError.code {
        case .userCancel, .appCancel, .systemCancel:
            return .cancelled
        case .userFallback:
            return .fallbackRequested
        case .biometryNotAvailable:
            return .failure(.biometryNotAvailable)
        case .biometryNotEnrolled:
            return .failure(.biometryNotEnrolled)
        case .biometryLockout:
            return .failure(.biometryLocked)
        case .authenticationFailed:
            return .failure(.authenticationFailed)
        default:
            NSLog("BiometricSecurity: Unexpected error - %@", laError.localizedDescription)
            return .failure(.unknown)
        }
    }
    
    // MARK: - Fallback Security
    
    /// Handles secure fallback authentication when biometrics fail
    /// - Parameters:
    ///   - completion: Completion handler for fallback result
    public static func handleSecureFallback(
        completion: @escaping (FallbackSecurityResult) -> Void
    ) {
        // Implement device passcode fallback with enhanced security
        let context = LAContext()
        
        // Check if device passcode is available
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            completion(.unavailable)
            return
        }
        
        // Set up secure passcode authentication
        context.localizedFallbackTitle = ""
        context.localizedCancelTitle = "Cancel"
        
        context.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: "Authenticate using your device passcode"
        ) { success, error in
            DispatchQueue.main.async {
                if success {
                    completion(.success)
                } else if let laError = error as? LAError,
                          laError.code == .userCancel {
                    completion(.cancelled)
                } else {
                    completion(.failed)
                }
            }
        }
    }
    
    // MARK: - Security State Management
    
    private static var failedAttemptCount = 0
    private static var lockoutEndTime: Date?
    
    /// Records a failed authentication attempt
    public static func recordFailedAttempt() {
        failedAttemptCount += 1
        
        if failedAttemptCount >= maxFailedAttempts {
            lockoutEndTime = Date().addingTimeInterval(TimeInterval(lockoutDurationMinutes * 60))
            NSLog("BiometricSecurity: Authentication locked out for %d minutes", lockoutDurationMinutes)
        }
    }
    
    /// Checks if authentication is currently locked out
    /// - Returns: True if locked out
    public static func isLockedOut() -> Bool {
        guard let lockoutEnd = lockoutEndTime else {
            return false
        }
        
        if Date() >= lockoutEnd {
            // Lockout expired
            clearLockout()
            return false
        }
        
        return true
    }
    
    /// Clears the authentication lockout
    public static func clearLockout() {
        failedAttemptCount = 0
        lockoutEndTime = nil
    }
    
    /// Resets authentication state on successful authentication
    public static func resetAuthenticationState() {
        clearLockout()
    }
}

// MARK: - Result Types

public enum BiometricSecurityResult {
    case success(domainState: Data)
    case cancelled
    case fallbackRequested
    case timeout
    case securityCompromised
    case failure(BiometricSecurityError)
}

public enum BiometricSecurityError {
    case biometryNotAvailable
    case biometryNotEnrolled
    case biometryLocked
    case authenticationFailed
    case unknown
}

public enum FallbackSecurityResult {
    case success
    case cancelled
    case failed
    case unavailable
}