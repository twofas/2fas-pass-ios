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
        guard let passwordID = UUID(uuidString: credentialRequest.credentialIdentity.recordIdentifier ?? ""),
              let encrypted = passwordInteractor.getEncryptedPasswordEntity(passwordID: passwordID),
              let encryptedPassword = encrypted.password else {
            Log("AutoFill - Missing password", module: .autofill)
            return nil
        }
        
        guard encrypted.protectionLevel == .normal else {
            return nil
        }
        
        guard passwordInteractor.loadTrustedKey() else {
            return nil
        }
        
        let username: String? = {
            guard let encryptedUsername = encrypted.username else {
                return nil
            }
            return passwordInteractor.decrypt(encryptedUsername, isPassword: false, protectionLevel: encrypted.protectionLevel)
        }()
        guard let password = passwordInteractor.decrypt(encryptedPassword, isPassword: true, protectionLevel: encrypted.protectionLevel) else {
            Log("AutoFill - Error while decrypting password", module: .autofill)
            return nil
        }
        
        Log("AutoFill - Complete get credential without user interaction", module: .autofill)
        return ASPasswordCredential(user: username ?? "", password: password)
    }
    
    func credential(for credentialRequest: any ASCredentialRequest) -> ASPasswordCredential? {
        guard let passwordID = UUID(uuidString: credentialRequest.credentialIdentity.recordIdentifier ?? "") else {
            return nil
        }
        return credential(for: passwordID)
    }
    
    func credential(for passwordID: PasswordID) -> ASPasswordCredential? {
        guard let password = passwordInteractor.getPassword(for: passwordID, checkInTrash: false) else {
            Log("AutoFill - Missing password", module: .autofill)
            return nil
        }
        let result = passwordInteractor.getPasswordEncryptedContents(for: passwordID, checkInTrash: false)
        switch result {
        case .success(let value):
            Log("AutoFill - Complete get credential", module: .autofill)
            return ASPasswordCredential(user: password.username ?? "", password: value ?? "")
        case .failure(let failure):
            Log("AutoFill - Failed get credential: \(failure)", module: .autofill)
            return nil
        }
    }
}
