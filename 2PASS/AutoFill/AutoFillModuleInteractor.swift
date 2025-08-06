// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import AuthenticationServices
import Data
import Common

protocol AutoFillModuleInteracting: AnyObject {
    func credential(for credentialRequest: any ASCredentialRequest) -> ASPasswordCredential?
    func credential(for passwordID: PasswordID) -> ASPasswordCredential?
    func credentialWithoutLogin(for credentialRequest: any ASCredentialRequest) -> ASPasswordCredential?
}

final class AutoFillModuleInteractor: AutoFillModuleInteracting {
    
    private let passwordInteractor: PasswordInteracting
    
    init(passwordInteractor: PasswordInteracting) {
        self.passwordInteractor = passwordInteractor
    }
    
    func credentialWithoutLogin(for credentialRequest: any ASCredentialRequest) -> ASPasswordCredential? {
        // Enhanced security validation for AutoFill request
        let validationResult = AutoFillSecurity.validateCredentialRequest(credentialRequest)
        
        switch validationResult {
        case .valid:
            break
        case .suspicious:
            Log("AutoFill - Suspicious credential request detected", module: .autofill, severity: .warning)
            // Continue but with extra caution
        case .rateLimited:
            Log("AutoFill - Request rate limited", module: .autofill, severity: .error)
            return nil
        case .invalidRequest, .invalidDomain:
            Log("AutoFill - Invalid credential request", module: .autofill, severity: .error)
            return nil
        case .suspiciousActivity:
            Log("AutoFill - Suspicious activity detected, blocking request", module: .autofill, severity: .error)
            return nil
        case .sessionExpired:
            Log("AutoFill - Session expired", module: .autofill, severity: .error)
            return nil
        case .invalid:
            Log("AutoFill - Invalid request", module: .autofill, severity: .error)
            return nil
        }
        
        guard let passwordID = UUID(uuidString: credentialRequest.credentialIdentity.recordIdentifier ?? ""),
              let encrypted = passwordInteractor.getEncryptedPasswordEntity(passwordID: passwordID),
              let encryptedPassword = encrypted.password else {
            Log("AutoFill - Missing password", module: .autofill)
            return nil
        }
        
        // Only allow normal protection level for automatic access
        guard encrypted.protectionLevel == .normal else {
            Log("AutoFill - Password requires user interaction due to protection level", module: .autofill)
            return nil
        }
        
        guard passwordInteractor.loadTrustedKey() else {
            Log("AutoFill - Failed to load trusted key", module: .autofill, severity: .error)
            return nil
        }
        
        var username: String? = nil
        var password: String? = nil
        
        // Securely decrypt username
        if let encryptedUsername = encrypted.username {
            username = passwordInteractor.decrypt(
                encryptedUsername, 
                isPassword: false, 
                protectionLevel: encrypted.protectionLevel
            )
        }
        
        // Securely decrypt password
        password = passwordInteractor.decrypt(
            encryptedPassword, 
            isPassword: true, 
            protectionLevel: encrypted.protectionLevel
        )
        
        guard let decryptedPassword = password else {
            Log("AutoFill - Error while decrypting password", module: .autofill, severity: .error)
            return nil
        }
        
        // Create secure credential
        guard let secureCredential = AutoFillSecurity.createSecureCredential(
            user: username ?? "",
            password: decryptedPassword,
            for: credentialRequest
        ) else {
            Log("AutoFill - Failed to create secure credential", module: .autofill, severity: .error)
            return nil
        }
        
        // Clear sensitive data from memory
        password?.secureClear()
        username?.secureClear()
        
        Log("AutoFill - Completed secure credential without user interaction", module: .autofill)
        return secureCredential
    }
    
    func credential(for credentialRequest: any ASCredentialRequest) -> ASPasswordCredential? {
        guard let passwordID = UUID(uuidString: credentialRequest.credentialIdentity.recordIdentifier ?? "") else {
            return nil
        }
        return credential(for: passwordID)
    }
    
    func credential(for passwordID: PasswordID) -> ASPasswordCredential? {
        guard let password = passwordInteractor.getPassword(for: passwordID, checkInTrash: false) else {
            Log("AutoFill - Missing password", module: .autofill, severity: .error)
            return nil
        }
        
        var result = passwordInteractor.getPasswordEncryptedContents(for: passwordID, checkInTrash: false)
        switch result {
        case .success(var value):
            // Ensure we have a password value
            guard let passwordValue = value else {
                Log("AutoFill - No password value found", module: .autofill, severity: .error)
                return nil
            }
            
            // Create secure credential  
            let sanitizedUsername = CryptographicSecurity.sanitizeStringInput(password.username ?? "")
            let credential = ASPasswordCredential(user: sanitizedUsername, password: passwordValue)
            
            // Securely clear sensitive data from memory
            value?.secureClear()
            
            Log("AutoFill - Completed secure get credential", module: .autofill)
            return credential
            
        case .failure(let failure):
            Log("AutoFill - Failed get credential: \(failure)", module: .autofill, severity: .error)
            return nil
        }
    }
}
