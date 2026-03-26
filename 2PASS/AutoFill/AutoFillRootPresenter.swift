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

    var isPasskeyRegistration: Bool { passkeyRegistrationRequest != nil }
    private(set) var passkeyRegistrationRequest: ASPasskeyCredentialRequest?
    
    private(set) var loginPresenter: LoginPresenter!
    private(set) var startupState: StartupInteractorStartResult?
    private let interactor: AutoFillModuleInteracting

    var savePasswordLoginChangeRequest: LoginDataChangeRequest? {
        guard #available(iOS 26.2, *) else { return nil }
        guard let request = savePasswordRequestStorage as? ASSavePasswordRequest else { return nil }
        return makeLoginChangeRequest(from: request)
    }
    
    var passkeyRegistrationRpID: String? {
        (passkeyRegistrationRequest?.credentialIdentity as? ASPasskeyCredentialIdentity)?.relyingPartyIdentifier
    }

    var passkeyRegistrationUserName: String? {
        (passkeyRegistrationRequest?.credentialIdentity as? ASPasskeyCredentialIdentity)?.userName
    }

    init(extensionContext: ASCredentialProviderExtensionContext, interactor: AutoFillModuleInteracting) {
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

    func prepareForPasskeyRegistration(for registrationRequest: any ASCredentialRequest) {
        if let passkeyRequest = registrationRequest as? ASPasskeyCredentialRequest {
            passkeyRegistrationRequest = passkeyRequest
        }
    }

    func prepare(for serviceIdentifiers: [ASCredentialServiceIdentifier]) {
        self.serviceIdentifiers = serviceIdentifiers
    }

    func provideWithoutUserInteraction(for credentialRequest: any ASCredentialRequest) {
        if let passkeyRequest = credentialRequest as? ASPasskeyCredentialRequest {
            Log("AutoFill - provideWithoutUserInteraction: passkey request", module: .autofill)
            if let assertion = interactor.passkeyAssertionWithoutLogin(for: passkeyRequest) {
                Log("AutoFill - provideWithoutUserInteraction: completing assertion", module: .autofill)
                extensionContext.completeAssertionRequest(using: assertion)
            } else {
                Log("AutoFill - provideWithoutUserInteraction: passkey assertion failed, requesting user interaction", module: .autofill)
                extensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.userInteractionRequired.rawValue))
            }
            return
        }

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

    func completePasskeyRegistration(name: String? = nil) {
        guard let request = passkeyRegistrationRequest else {
            Log("AutoFill - Passkey registration: no request stored", module: .autofill)
            return
        }

        Task { @MainActor in
            do {
                let credential = try await interactor.registerPasskey(for: request, name: name)
                Log("AutoFill - Passkey registration: completing with credential", module: .autofill)
                extensionContext.completeRegistrationRequest(using: credential) { expired in
                    Log("AutoFill - Passkey registration completion handler: expired=\(expired)", module: .autofill)
                }
            } catch {
                Log("AutoFill - Passkey registration failed: \(error)", module: .autofill, severity: .error)
                extensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.failed.rawValue))
            }
        }
    }

    @available(iOS 18.0, *)
    func performPasskeyRegistrationWithoutUserInteractionIfPossible(_ request: ASPasskeyCredentialRequest) {
        Task { @MainActor in
            await refreshState()

            guard interactor.canSaveWithoutLogin() else {
                Log("AutoFill - Passkey registration without UI: conditions not met", module: .autofill)
                extensionContext.cancelRequest(withError: NSError(
                    domain: ASExtensionErrorDomain,
                    code: ASExtensionError.userInteractionRequired.rawValue
                ))
                return
            }

            do {
                let credential = try await interactor.registerPasskey(for: request, name: nil)
                Log("AutoFill - Passkey registration without UI: completing", module: .autofill)
                extensionContext.completeRegistrationRequest(using: credential) { expired in
                    Log("AutoFill - Passkey registration without UI completion handler: expired=\(expired)", module: .autofill)
                }
            } catch {
                Log("AutoFill - Passkey registration without UI failed: \(error)", module: .autofill, severity: .error)
                extensionContext.cancelRequest(withError: NSError(
                    domain: ASExtensionErrorDomain,
                    code: ASExtensionError.failed.rawValue
                ))
            }
        }
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
    
    func completeSavePassword() {
        guard #available(iOS 26.2, *) else { return }
        guard let request = savePasswordRequestStorage as? ASSavePasswordRequest else {
            Log("AutoFill - Save password: no request stored", module: .autofill)
            return
        }

        Task { @MainActor in
            do {
                try await interactor.savePassword(changeRequest: makeLoginChangeRequest(from: request))
                Log("AutoFill - Save password: completing", module: .autofill)
                extensionContext.completeSavePasswordRequest(completionHandler: { _ in })
            } catch {
                Log("AutoFill - Save password: failed \(error)", module: .autofill, severity: .error)
                extensionContext.cancelRequest(withError: NSError(
                    domain: ASExtensionErrorDomain,
                    code: ASExtensionError.failed.rawValue
                ))
            }
        }
    }

    private func onLoginSuccessful() {
        if isSavePasswordFlow || isPasskeyRegistration {
            Task { @MainActor in
                await refreshState()
            }
            return
        }

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
        if let passkeyRequest = credentialRequest as? ASPasskeyCredentialRequest {
            return completeAssertionRequest(using: passkeyRequest)
        }

        guard let credential = interactor.credential(for: credentialRequest) else {
            return false
        }

        extensionContext.completeRequest(withSelectedCredential: credential)
        return true
    }

    private func completeAssertionRequest(using request: ASPasskeyCredentialRequest) -> Bool {
        Log("AutoFill - completeAssertionRequest: attempting passkey assertion after login", module: .autofill)
        guard let assertion = interactor.passkeyAssertion(for: request) else {
            Log("AutoFill - completeAssertionRequest: assertion failed", module: .autofill)
            return false
        }

        Log("AutoFill - completeAssertionRequest: completing assertion", module: .autofill)
        extensionContext.completeAssertionRequest(using: assertion)
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
