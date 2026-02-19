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
    @MainActor
    func savePassword(changeRequest: LoginDataChangeRequest) async throws
    func sendSaveSuccessNotification() async
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
        self.autoFillCredentialsInteractor = autoFillCredentialsInteractor
        self.passwordGeneratorInteractor = passwordGeneratorInteractor
        self.pushNotificationsInteractor = pushNotificationsInteractor
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
