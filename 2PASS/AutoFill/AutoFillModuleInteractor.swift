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
    func initialize()
    func start() async -> StartupInteractorStartResult
}

final class AutoFillModuleInteractor: AutoFillModuleInteracting {
    
    private let passwordInteractor: PasswordInteracting
    private let startupInteractor: StartupInteracting
    
    init(passwordInteractor: PasswordInteracting, startupInteractor: StartupInteracting) {
        self.passwordInteractor = passwordInteractor
        self.startupInteractor = startupInteractor
    }
    
    func initialize() {
        startupInteractor.initialize()
    }
    
    func start() async -> StartupInteractorStartResult {
        await startupInteractor.start()
    }
    
    func credentialWithoutLogin(for credentialRequest: any ASCredentialRequest) -> ASPasswordCredential? {
        guard let passwordID = UUID(uuidString: credentialRequest.credentialIdentity.recordIdentifier ?? ""),
              let encrypted = passwordInteractor.getEncryptedItemEntity(itemID: passwordID) else {
            Log("AutoFill - Missing password", module: .autofill)
            return nil
        }
        
        guard encrypted.protectionLevel == .normal else {
            return nil
        }
        
        guard passwordInteractor.loadTrustedKey() else {
            return nil
        }
        
        guard let content = passwordInteractor.decryptContent(PasswordItemContent.self, from: encrypted.content, protectionLevel: encrypted.protectionLevel) else {
            return nil
        }
        
        guard let passwordEnc = content.password, let password = passwordInteractor.decrypt(passwordEnc, isPassword: true, protectionLevel: encrypted.protectionLevel) else {
            Log("AutoFill - Error while decrypting password", module: .autofill)
            return nil
        }
        
        Log("AutoFill - Complete get credential without user interaction", module: .autofill)
        return ASPasswordCredential(user: content.username ?? "", password: password)
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
