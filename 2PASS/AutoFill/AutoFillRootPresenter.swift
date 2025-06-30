// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import AuthenticationServices
import Data
import CommonUI

@Observable
final class AutoFillRootPresenter {
    
    let extensionContext: ASCredentialProviderExtensionContext
    let startupResult: StartupInteractorStartResult
    
    private(set) var serviceIdentifiers: [ASCredentialServiceIdentifier] = []
    private(set) var credentialRequest: (any ASCredentialRequest)?
    private(set) var isTextToInsert: Bool = false
    private(set) var isLogged = false
    private(set) var loginPresenter: LoginPresenter!
    private let interactor: AutoFillModuleInteracting
    
    init(extensionContext: ASCredentialProviderExtensionContext, startupResult: StartupInteractorStartResult, interactor: AutoFillModuleInteracting) {
        self.extensionContext = extensionContext
        self.startupResult = startupResult
        self.interactor = interactor
        
        let loginInteractor = ModuleInteractorFactory.shared.loginModuleInteractor(config: .init(allowBiometrics: true, loginType: .login))
        loginPresenter = LoginPresenter(loginSuccessful: { [weak self] in
            self?.onLoginSuccessful()
        }, interactor: loginInteractor)
    }
    
    func startBiometryIfAvailable() {
        loginPresenter.startBiometryIfAvailable()
    }
    
    func prepareForTextToInsert() {
        isTextToInsert = true
    }
    
    func prepare(for serviceIdentifiers: [ASCredentialServiceIdentifier]) {
        self.serviceIdentifiers = serviceIdentifiers
    }
    
    func provideWithoutUserInteraction(for credentialRequest: any ASCredentialRequest) {
        if let credential = interactor.credentialWithoutLogin(for: credentialRequest) {
            extensionContext.completeRequest(withSelectedCredential: credential)
        } else {
            extensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code:ASExtensionError.userInteractionRequired.rawValue))
        }
    }

    func provide(for credentialRequest: any ASCredentialRequest) {
        self.credentialRequest = credentialRequest
    }
    
    func onCancel() {
        extensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.userCanceled.rawValue))
    }
    
    private func onLoginSuccessful() {
        if let credentialRequest {
            if completeCredentialRequest(credentialRequest) == false {
                prepare(for: [credentialRequest.credentialIdentity.serviceIdentifier])
                isLogged = true
            }
        } else {
            isLogged = true
        }
    }

    private func completeCredentialRequest(_ credentialRequest: any ASCredentialRequest) -> Bool {
        guard let credential = interactor.credential(for: credentialRequest) else {
            return false
        }
        
        extensionContext.completeRequest(withSelectedCredential: credential)
        return true
    }
}
