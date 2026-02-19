// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import AuthenticationServices
import Data
import CommonUI
import Common

@Observable
final class AutoFillRootPresenter {
    let extensionContext: ASCredentialProviderExtensionContext

    private(set) var serviceIdentifiers: [ASCredentialServiceIdentifier] = []
    private(set) var credentialRequest: (any ASCredentialRequest)?
    private(set) var isTextToInsert: Bool = false
    private(set) var isGeneratePasswordFlow: Bool = false
    private(set) var isSavePasswordFlow: Bool = false
    private var savePasswordRequestStorage: Any? /// Stored as `Any` because `ASSavePasswordRequest` requires iOS 26.2+
    private(set) var loginPresenter: LoginPresenter!
    private(set) var startupState: StartupInteractorStartResult?
    private let interactor: AutoFillModuleInteracting

    var savePasswordLoginChangeRequest: LoginDataChangeRequest? {
        guard #available(iOS 26.2, *) else { return nil }
        guard let request = savePasswordRequestStorage as? ASSavePasswordRequest else { return nil }
        return makeLoginChangeRequest(from: request)
    }

    init(
        extensionContext: ASCredentialProviderExtensionContext,
        interactor: AutoFillModuleInteracting
    ) {
        self.extensionContext = extensionContext
        self.interactor = interactor

        let loginInteractor = ModuleInteractorFactory.shared.loginModuleInteractor(config: .init(allowBiometrics: true, loginType: .login, showForgotPassword: false))
        loginPresenter = LoginPresenter(loginSuccessful: { [weak self] in
            self?.onLoginSuccessful()
        }, interactor: loginInteractor)
    }

    func viewDidAppear() {
        Task { @MainActor in
            await refreshState()
            guard isGeneratePasswordFlow == false else { return }
            if startupState == .login {
                startBiometryIfAvailable()
            }
        }
    }

    func viewWillDisappear() {
        interactor.logoutFromApp()
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
        Task { @MainActor in
            await refreshState()
            
            if let credential = interactor.credentialWithoutLogin(for: credentialRequest) {
                extensionContext.completeRequest(withSelectedCredential: credential)
            } else {
                extensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.userInteractionRequired.rawValue))
            }
        }
    }

    func provide(for credentialRequest: any ASCredentialRequest) {
        self.credentialRequest = credentialRequest
    }

    func onCancel() {
        extensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.userCanceled.rawValue))
    }

    // MARK: - Generate Password

    @available(iOS 26.2, *)
    func generatePasswordWithoutUserInteraction() {
        let password = interactor.generatePassword()
        Log("AutoFill - Generate password: completed", module: .autofill)
        
        extensionContext.completeGeneratePasswordRequest(
            results: [ASGeneratedPassword(kind: .strong, value: password)]
        ) { _ in }
    }
    
    @available(iOS 26.2, *)
    func prepareForGeneratePassword(_: ASGeneratePasswordsRequest) {
        isGeneratePasswordFlow = true
    }

    func completeGeneratedPassword(_ password: String) {
        guard #available(iOS 26.2, *) else { return }

        guard password.isEmpty == false else {
            extensionContext.cancelRequest(withError: NSError(
                domain: ASExtensionErrorDomain,
                code: ASExtensionError.failed.rawValue
            ))
            return
        }

        Log("AutoFill - Generate password: completing", module: .autofill)
        extensionContext.completeGeneratePasswordRequest(
            results: [ASGeneratedPassword(kind: .strong, value: password)]
        ) { _ in }
    }

    // MARK: - Save Password

    @available(iOS 26.2, *)
    func savePasswordWithoutUserInteraction(_ request: ASSavePasswordRequest) {
        Task { @MainActor in
            guard request.event != .generatedPasswordFilled else {
                await extensionContext.completeSavePasswordRequest()
                return
            }
            
            await refreshState()
            
            guard interactor.canSaveWithoutLogin() else {
                Log("AutoFill - Save password without UI: needs login, requesting interaction", module: .autofill)
                extensionContext.cancelRequest(withError: NSError(
                    domain: ASExtensionErrorDomain,
                    code: ASExtensionError.userInteractionRequired.rawValue
                ))
                return
            }
            
            do {
                try await interactor.savePassword(changeRequest: makeLoginChangeRequest(from: request))
                Log("AutoFill - Save password without UI: completed", module: .autofill)
                await interactor.sendSaveSuccessNotification()
                await extensionContext.completeSavePasswordRequest()
            } catch {
                Log("AutoFill - Save password without UI: failed \(error)", module: .autofill, severity: .error)
                extensionContext.cancelRequest(withError: NSError(
                    domain: ASExtensionErrorDomain,
                    code: ASExtensionError.failed.rawValue
                ))
            }
        }
    }

    @available(iOS 26.2, *)
    func prepareForSavePassword(_ request: ASSavePasswordRequest) {
        isSavePasswordFlow = true
        savePasswordRequestStorage = request
    }

    func onSavePasswordEditorClosed(_ result: SaveItemResult) {
        guard #available(iOS 26.2, *) else { return }

        switch result {
        case .success:
            Log("AutoFill - Save password editor: completing", module: .autofill)
            Task { @MainActor in
                await interactor.sendSaveSuccessNotification()
                extensionContext.completeSavePasswordRequest(completionHandler: { _ in })
            }
        case .failure(let error):
            switch error {
            case .userCancelled:
                Log("AutoFill - Save password editor: cancelled", module: .autofill)
                extensionContext.cancelRequest(withError: NSError(
                    domain: ASExtensionErrorDomain,
                    code: ASExtensionError.userCanceled.rawValue
                ))
            case .uriNormalizationFailed, .interactorError:
                Log("AutoFill - Save password editor: failed \(error)", module: .autofill, severity: .error)
                extensionContext.cancelRequest(withError: NSError(
                    domain: ASExtensionErrorDomain,
                    code: ASExtensionError.failed.rawValue
                ))
            }
        }
    }

    private func onLoginSuccessful() {
        if let credentialRequest {
            if completeCredentialRequest(credentialRequest) == false {
                prepare(for: [credentialRequest.credentialIdentity.serviceIdentifier])
            }
        }

        Task { @MainActor in
            await refreshState()
        }
    }

    private func completeCredentialRequest(_ credentialRequest: any ASCredentialRequest) -> Bool {
        guard let credential = interactor.credential(for: credentialRequest) else {
            return false
        }

        extensionContext.completeRequest(withSelectedCredential: credential)
        return true
    }

    private func refreshState() async {
        startupState = await interactor.start()
    }

    @available(iOS 26.2, *)
    private func makeLoginChangeRequest(from request: ASSavePasswordRequest) -> LoginDataChangeRequest {
        let serviceIdentifier = request.serviceIdentifier.identifier
        let username = request.credential.user
        let password = request.credential.password

        return LoginDataChangeRequest(
            name: request.title ?? request.serviceIdentifier.displayName,
            username: username.isEmpty ? nil : .value(username),
            password: password.isEmpty ? nil : .value(password),
            uris: serviceIdentifier.isEmpty ? nil : [PasswordURI(uri: serviceIdentifier, match: .domain)]
        )
    }
}
