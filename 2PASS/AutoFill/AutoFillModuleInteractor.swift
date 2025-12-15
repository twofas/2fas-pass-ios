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
    func credential(for itemID: ItemID) -> ASPasswordCredential?
    func credentialWithoutLogin(for credentialRequest: any ASCredentialRequest) -> ASPasswordCredential?
    func initialize()
    func start() async -> StartupInteractorStartResult
    func logoutFromApp()
}

final class AutoFillModuleInteractor: AutoFillModuleInteracting {
    
    private let itemsInteractor: ItemsInteracting
    private let startupInteractor: StartupInteracting
    private let securityInteractor: SecurityInteracting
    
    init(itemsInteractor: ItemsInteracting, startupInteractor: StartupInteracting, securityInteractor: SecurityInteracting) {
        self.itemsInteractor = itemsInteractor
        self.startupInteractor = startupInteractor
        self.securityInteractor = securityInteractor
    }
    
    func initialize() {
        startupInteractor.initialize()
    }
    
    func start() async -> StartupInteractorStartResult {
        await startupInteractor.start()
    }
    
    func credentialWithoutLogin(for credentialRequest: any ASCredentialRequest) -> ASPasswordCredential? {
        guard let itemID = UUID(uuidString: credentialRequest.credentialIdentity.recordIdentifier ?? ""),
              let encrypted = itemsInteractor.getEncryptedItemEntity(itemID: itemID) else {
            Log("AutoFill - Missing password", module: .autofill)
            return nil
        }
        
        guard encrypted.protectionLevel == .normal else {
            return nil
        }
        
        guard itemsInteractor.loadTrustedKey() else {
            return nil
        }
        
        guard let content = itemsInteractor.decryptContent(LoginItemData.Content.self, from: encrypted.content, protectionLevel: encrypted.protectionLevel) else {
            return nil
        }
        
        guard let passwordEnc = content.password, let password = itemsInteractor.decrypt(passwordEnc, isSecureField: true, protectionLevel: encrypted.protectionLevel) else {
            Log("AutoFill - Error while decrypting password", module: .autofill)
            return nil
        }
        
        Log("AutoFill - Complete get credential without user interaction", module: .autofill)
        return ASPasswordCredential(user: content.username ?? "", password: password)
    }
    
    func credential(for credentialRequest: any ASCredentialRequest) -> ASPasswordCredential? {
        guard let itemID = UUID(uuidString: credentialRequest.credentialIdentity.recordIdentifier ?? "") else {
            return nil
        }
        return credential(for: itemID)
    }
    
    func credential(for itemID: ItemID) -> ASPasswordCredential? {
        guard let loginItem = itemsInteractor.getItem(for: itemID, checkInTrash: false)?.asLoginItem else {
            Log("AutoFill - Missing password", module: .autofill)
            return nil
        }
        
        guard let password = loginItem.password else {
            Log("AutoFill - Complete get credential without password", module: .autofill)
            return ASPasswordCredential(user: loginItem.username ?? "", password: "")
        }
        
        if let decryptedPassword = itemsInteractor.decrypt(password, isSecureField: true, protectionLevel: loginItem.protectionLevel) {
            Log("AutoFill - Complete get credential", module: .autofill)
            return ASPasswordCredential(user: loginItem.username ?? "", password: decryptedPassword)
        } else {
            Log("AutoFill - Failed get credential", module: .autofill)
            return nil
        }
    }
    
    func logoutFromApp() {
        securityInteractor.logout()
    }
}
