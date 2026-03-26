// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import AuthenticationServices
import Data
import Common

enum PasskeyRegistrationError: Error {
    case encryptionError
    case saveError
}

protocol AutoFillModuleInteracting: AnyObject {
    var isScreenCaptureAllowed: Bool { get }
    var screenCaptureAllowedUntil: Date? { get }
    func credential(for credentialRequest: any ASCredentialRequest) -> ASPasswordCredential?
    func credential(for itemID: ItemID) -> ASPasswordCredential?
    func credentialWithoutLogin(for credentialRequest: any ASCredentialRequest) -> ASPasswordCredential?

    @MainActor
    func savePassword(changeRequest: LoginDataChangeRequest) async throws
    func sendSaveSuccessNotification() async

    func passkeyAssertion(for request: ASPasskeyCredentialRequest) -> ASPasskeyAssertionCredential?
    func passkeyAssertion(for itemID: ItemID, clientDataHash: Data) -> ASPasskeyAssertionCredential?
    func passkeyAssertionWithoutLogin(for request: ASPasskeyCredentialRequest) -> ASPasskeyAssertionCredential?
    func registerPasskey(for request: ASPasskeyCredentialRequest, name: String?) async throws -> ASPasskeyRegistrationCredential

    func canSaveWithoutLogin() -> Bool
    func generatePassword() -> String
    func initialize()
    @MainActor func start() async -> StartupInteractorStartResult
    func logoutFromApp()
}

final class AutoFillModuleInteractor: AutoFillModuleInteracting {

    private let itemsInteractor: ItemsInteracting
    private let startupInteractor: StartupInteracting
    private let securityInteractor: SecurityInteracting
    private let configInteractor: ConfigInteracting
    private let uriInteractor: URIInteracting
    private let loginItemInteractor: LoginItemInteracting
    private let passkeyItemInteractor: PasskeyItemInteracting
    private let autoFillCredentialsInteractor: AutoFillCredentialsInteracting
    private let passwordGeneratorInteractor: PasswordGeneratorInteracting
    private let pushNotificationsInteractor: PushNotificationsInteracting

    init(
        itemsInteractor: ItemsInteracting,
        startupInteractor: StartupInteracting,
        securityInteractor: SecurityInteracting,
        configInteractor: ConfigInteracting,
        uriInteractor: URIInteracting,
        loginItemInteractor: LoginItemInteracting,
        passkeyItemInteractor: PasskeyItemInteracting,
        autoFillCredentialsInteractor: AutoFillCredentialsInteracting,
        passwordGeneratorInteractor: PasswordGeneratorInteracting,
        pushNotificationsInteractor: PushNotificationsInteracting
    ) {
        self.itemsInteractor = itemsInteractor
        self.startupInteractor = startupInteractor
        self.securityInteractor = securityInteractor
        self.configInteractor = configInteractor
        self.uriInteractor = uriInteractor
        self.loginItemInteractor = loginItemInteractor
        self.passkeyItemInteractor = passkeyItemInteractor
        self.autoFillCredentialsInteractor = autoFillCredentialsInteractor
        self.passwordGeneratorInteractor = passwordGeneratorInteractor
        self.pushNotificationsInteractor = pushNotificationsInteractor
    }

    var isScreenCaptureAllowed: Bool {
        configInteractor.isScreenCaptureAllowed
    }

    var screenCaptureAllowedUntil: Date? {
        configInteractor.screenCaptureAllowedUntil
    }

    func initialize() {
        startupInteractor.initialize()
    }

    @MainActor
    func start() async -> StartupInteractorStartResult {
        await startupInteractor.start()
    }

    // MARK: - Password Credential

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

    // MARK: - Save Password

    func canSaveWithoutLogin() -> Bool {
        let defaultProtectionLevel = configInteractor.currentDefaultProtectionLevel
        guard defaultProtectionLevel == .normal else {
            Log("AutoFill - Save password without UI: default protection level is \(defaultProtectionLevel.rawValue), user interaction required", module: .autofill)
            return false
        }
        
        return itemsInteractor.loadTrustedKey()
    }
    
    // MARK: - Passkey Assertion

    func passkeyAssertionWithoutLogin(for request: ASPasskeyCredentialRequest) -> ASPasskeyAssertionCredential? {
        guard let identity = request.credentialIdentity as? ASPasskeyCredentialIdentity else {
            Log("AutoFill - Passkey assertion (no login): not a passkey identity", module: .autofill)
            return nil
        }

        let recordID = identity.recordIdentifier ?? "(nil)"
        Log("AutoFill - Passkey assertion (no login): recordIdentifier=\(recordID), rpID=\(identity.relyingPartyIdentifier)", module: .autofill)

        guard let itemID = UUID(uuidString: recordID),
              let encrypted = itemsInteractor.getEncryptedItemEntity(itemID: itemID) else {
            Log("AutoFill - Passkey assertion (no login): item not found for \(recordID)", module: .autofill)
            return nil
        }

        guard encrypted.protectionLevel == .normal else {
            Log("AutoFill - Passkey assertion (no login): requires elevated protection", module: .autofill)
            return nil
        }

        guard itemsInteractor.loadTrustedKey() else {
            Log("AutoFill - Passkey assertion (no login): trusted key not available", module: .autofill)
            return nil
        }

        switch encrypted.contentType {
        case .passkey:
            guard let content = itemsInteractor.decryptContent(PasskeyItemContent.self, from: encrypted.content, protectionLevel: encrypted.protectionLevel) else {
                Log("AutoFill - Passkey assertion (no login): passkey content decryption failed", module: .autofill)
                return nil
            }
            return makePasskeyAssertionFromPasskeyItem(content: content, clientDataHash: request.clientDataHash, protectionLevel: encrypted.protectionLevel)

        default:
            return nil
        }
    }

    func passkeyAssertion(for request: ASPasskeyCredentialRequest) -> ASPasskeyAssertionCredential? {
        guard let identity = request.credentialIdentity as? ASPasskeyCredentialIdentity else {
            Log("AutoFill - Passkey assertion: not a passkey identity", module: .autofill)
            return nil
        }

        let recordID = identity.recordIdentifier ?? "(nil)"
        Log("AutoFill - Passkey assertion: recordIdentifier=\(recordID), rpID=\(identity.relyingPartyIdentifier)", module: .autofill)

        guard let itemID = UUID(uuidString: recordID) else {
            Log("AutoFill - Passkey assertion: invalid UUID in recordIdentifier", module: .autofill)
            return nil
        }

        guard let item = itemsInteractor.getItem(for: itemID, checkInTrash: false) else {
            Log("AutoFill - Passkey assertion: item not found for \(itemID)", module: .autofill)
            return nil
        }

        if let passkeyItem = item.asPasskeyItem {
            Log("AutoFill - Passkey assertion: found passkey item", module: .autofill)
            return makePasskeyAssertionFromPasskeyItem(content: passkeyItem.content, clientDataHash: request.clientDataHash, protectionLevel: passkeyItem.protectionLevel)
        } else {
            Log("AutoFill - Passkey assertion: item is not a passkey", module: .autofill)
            return nil
        }
    }

    func passkeyAssertion(for itemID: ItemID, clientDataHash: Data) -> ASPasskeyAssertionCredential? {
        guard let item = itemsInteractor.getItem(for: itemID, checkInTrash: false) else {
            Log("AutoFill - Passkey assertion (by itemID): item not found", module: .autofill)
            return nil
        }

        if let passkeyItem = item.asPasskeyItem {
            Log("AutoFill - Passkey assertion (by itemID): found passkey item", module: .autofill)
            return makePasskeyAssertionFromPasskeyItem(content: passkeyItem.content, clientDataHash: clientDataHash, protectionLevel: passkeyItem.protectionLevel)
        } else {
            return nil
        }
    }

    // MARK: - Passkey Registration

    func registerPasskey(for request: ASPasskeyCredentialRequest, name: String?) async throws -> ASPasskeyRegistrationCredential {
        guard let identity = request.credentialIdentity as? ASPasskeyCredentialIdentity else {
            Log("AutoFill - Passkey registration: not a passkey identity", module: .autofill, severity: .error)
            throw PasskeyRegistrationError.saveError
        }

        let rpID = identity.relyingPartyIdentifier
        let userHandle = identity.userHandle
        let userName = identity.userName
        Log("AutoFill - Passkey registration: rpID=\(rpID), user=\(userName)", module: .autofill)

        let keyPair = PasskeyCryptoService.generateKeyPair()

        let authData = PasskeyCryptoService.buildRegistrationAuthenticatorData(
            rpID: rpID,
            credentialID: keyPair.credentialID,
            publicKeyCOSE: keyPair.publicKeyCOSE
        )
        let attestationObject = PasskeyCryptoService.buildAttestationObject(authenticatorData: authData)

        let itemID = ItemID()
        let now = Date()
        do {
            try passkeyItemInteractor.createPasskey(
                id: itemID,
                metadata: ItemMetadata(
                    creationDate: now,
                    modificationDate: now,
                    protectionLevel: .normal,
                    trashedStatus: .no,
                    tagIds: nil
                ),
                name: name ?? rpID,
                credentialID: keyPair.credentialID,
                rpID: rpID,
                username: userName,
                userHandle: userHandle,
                privateKey: keyPair.privateKeyDER
            )
        } catch {
            Log("AutoFill - Passkey registration: save failed: \(error)", module: .autofill, severity: .error)
            throw PasskeyRegistrationError.saveError
        }

        itemsInteractor.saveStorage()

        try? await autoFillCredentialsInteractor.addPasskeySuggestion(
            itemID: itemID,
            rpID: rpID,
            username: userName,
            credentialID: keyPair.credentialID,
            userHandle: userHandle
        )

        Log("AutoFill - Passkey registration completed for \(rpID)", module: .autofill)
        return ASPasskeyRegistrationCredential(
            relyingParty: rpID,
            clientDataHash: request.clientDataHash,
            credentialID: keyPair.credentialID,
            attestationObject: attestationObject
        )
    }

    // MARK: - Save Password

    func generatePassword() -> String {
        let config = PasswordGenerateConfig(
            length: passwordGeneratorInteractor.prefersPasswordLength,
            hasDigits: true,
            hasUppercase: true,
            hasSpecial: true
        )
        return passwordGeneratorInteractor.generatePassword(using: config)
    }

    func sendSaveSuccessNotification() async {
        await pushNotificationsInteractor.send(String(localized: .autofillSaveLoginToastSuccess))
    }

    @MainActor
    func savePassword(changeRequest: LoginDataChangeRequest) async throws {
        let itemID = ItemID()
        let now = Date()
        let defaultProtectionLevel = configInteractor.currentDefaultProtectionLevel
        let serviceIdentifier = changeRequest.uris?.first?.uri
        let iconDomain = serviceIdentifier.flatMap { uriInteractor.extractDomain(from: $0) }

        try loginItemInteractor.createLogin(
            id: itemID,
            metadata: ItemMetadata(
                creationDate: now,
                modificationDate: now,
                protectionLevel: defaultProtectionLevel,
                trashedStatus: .no,
                tagIds: nil
            ),
            name: changeRequest.name ?? serviceIdentifier,
            username: changeRequest.username?.value,
            password: changeRequest.password?.value,
            notes: changeRequest.notes,
            iconType: .domainIcon(iconDomain),
            uris: changeRequest.uris
        )
        itemsInteractor.saveStorage()

        try? await autoFillCredentialsInteractor.addSuggestions(
            itemID: itemID,
            username: changeRequest.username?.value,
            uris: changeRequest.uris,
            protectionLevel: defaultProtectionLevel
        )

        if let serviceIdentifier {
            Log("AutoFill - Save password completed for \(serviceIdentifier)", module: .autofill)
        } else {
            Log("AutoFill - Save password completed", module: .autofill)
        }
    }

    func logoutFromApp() {
        securityInteractor.logout()
    }
}

// MARK: - Private

private extension AutoFillModuleInteractor {

    func makePasskeyAssertionFromPasskeyItem(
        content: PasskeyItemContent,
        clientDataHash: Data,
        protectionLevel: ItemProtectionLevel
    ) -> ASPasskeyAssertionCredential? {
        guard let privateKeyDER = itemsInteractor.decryptData(content.privateKey, isSecureField: true, protectionLevel: protectionLevel) else {
            Log("AutoFill - Passkey assertion: private key decryption failed", module: .autofill)
            return nil
        }

        let authenticatorData = PasskeyCryptoService.buildAssertionAuthenticatorData(rpID: content.rpId)

        guard let signature = try? PasskeyCryptoService.sign(
            authenticatorData: authenticatorData,
            clientDataHash: clientDataHash,
            privateKeyDER: privateKeyDER
        ) else {
            Log("AutoFill - Passkey assertion: signing failed", module: .autofill)
            return nil
        }

        Log("AutoFill - Passkey assertion completed for \(content.rpId)", module: .autofill)
        return ASPasskeyAssertionCredential(
            userHandle: content.userHandle,
            relyingParty: content.rpId,
            signature: signature,
            clientDataHash: clientDataHash,
            authenticatorData: authenticatorData,
            credentialID: content.credentialId
        )
    }
}
