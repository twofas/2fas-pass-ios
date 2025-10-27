// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common
import CryptoKit

extension ConnectInteractor {

    // MARK: - Schema V1 Action Handlers

    func handleNewLoginResponse(_ data: Data, keys: SessionKeys, shouldPerfromAction: (ConnectAction) async -> ConnectContinuation) async throws -> ConnectSchemaV1.ConnectActionItemData {
        let actionRequestData = try mainRepository.jsonDecoder.decode(ConnectSchemaV1.ConnectActionRequest<ConnectSchemaV1.ConnectActionAddRequestData>.self, from: data)

        let encryptionNewPasswordKey = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: keys.sessionKey,
            salt: keys.hkdfSalt,
            info: Keys.Connect.newPassword.data(using: .utf8)!,
            outputByteCount: 32
        )

        var newPassword: String?
        if let newPasswordDataEnc = actionRequestData.data.passwordEnc, let newPasswordData =  mainRepository.decrypt(newPasswordDataEnc, key: encryptionNewPasswordKey) {
            newPassword = String(data: newPasswordData, encoding: .utf8)
        }

        let name = uriInteractor.extractDomain(from: actionRequestData.data.url) ?? actionRequestData.data.url

        let changeRequst = LoginDataChangeRequest(
            name: name,
            username: .value(actionRequestData.data.username.value),
            password: actionRequestData.data.usernamePasswordMobile ? .generate : newPassword.map { .value($0) },
            uris: [PasswordURI(uri: actionRequestData.data.url, match: .domain)]
        )

        let (accepted, newPasswordId) = await shouldPerfromAction(.changeRequest(.addLogin(changeRequst)))

        guard accepted else {
            throw ConnectError.cancelled
        }

        guard let newPasswordId else {
            throw ConnectError.badData
        }

        let encryptionPasswordKey: (ItemProtectionLevel) -> SymmetricKey? = { protectionLevel in
            let infoData: Data? = {
                switch protectionLevel {
                case .normal:
                    Keys.Connect.passwordTier3.data(using: .utf8)!
                case .confirm:
                    Keys.Connect.passwordTier2.data(using: .utf8)!
                case .topSecret:
                    nil
                }
            }()

            guard let infoData else {
                return nil
            }

            return HKDF<SHA256>.deriveKey(
                inputKeyMaterial: keys.sessionKey,
                salt: keys.hkdfSalt,
                info: infoData,
                outputByteCount: 32
            )
        }

        guard let deviceID = mainRepository.deviceID else {
            throw ConnectError.missingDeviceId
        }

        let connectLogin = try await connectExportInteractor.prepareItemForConnectExport(
            id: newPasswordId,
            deviceId: deviceID,
            secureFieldEncryptionKeyProvider: encryptionPasswordKey
        )
        let actionData = ConnectSchemaV1.ConnectActionItemData(
            type: .newLogin,
            status: connectLogin.securityType == ItemProtectionLevel.topSecret.intValue ? .addedInT1 : .added,
            login: connectLogin.securityType == ItemProtectionLevel.topSecret.intValue ? nil : connectLogin
        )
        return actionData
    }

    func handlePasswordRequestResponse(_ data: Data, keys: SessionKeys, shouldPerfromAction: (ConnectAction) async -> ConnectContinuation) async throws -> ConnectSchemaV1.ConnectActionPasswordData {
        let actionRequestData = try mainRepository.jsonDecoder.decode(ConnectSchemaV1.ConnectActionRequest<ConnectSchemaV1.ConnectActionPasswordRequestData>.self, from: data)
        let itemID = actionRequestData.data.loginId

        guard let loginItem = itemsInteractor.getItem(for: itemID, checkInTrash: false)?.asLoginItem else {
            throw ConnectError.missingItem
        }

        let accepted = await shouldPerfromAction(.sifRequest(.login(loginItem))).accepted

        guard accepted else {
            throw ConnectError.cancelled
        }

        let passwordValue = {
            if let password = loginItem.password {
                return itemsInteractor.decrypt(password, isSecureField: true, protectionLevel: loginItem.protectionLevel)
            } else {
                return ""
            }
        }()

        guard let passwordValue else {
            throw ConnectError.decryptionFailure
        }

        let encryptionPasswordKey = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: keys.sessionKey,
            salt: keys.hkdfSalt,
            info: Keys.Connect.passwordTier2.data(using: .utf8)!,
            outputByteCount: 32
        )

        guard let nonceP = mainRepository.generateRandom(byteCount: Config.Connect.nonceByteCount),
              let passwordValueData = passwordValue.data(using: .utf8),
              let passwordEnc = mainRepository.encrypt(passwordValueData, key: encryptionPasswordKey, nonce: nonceP) else {
            throw ConnectError.encryptionFailure
        }

        return ConnectSchemaV1.ConnectActionPasswordData(type: .passwordRequest, status: .accept, passwordEnc: passwordEnc)
    }

    func handleUpdateLoginResponse(_ data: Data, keys: SessionKeys, shouldPerfromAction: (ConnectAction) async -> ConnectContinuation) async throws -> ConnectSchemaV1.ConnectActionItemData {
        let actionRequestData = try mainRepository.jsonDecoder.decode(ConnectSchemaV1.ConnectActionRequest<ConnectSchemaV1.ConnectActionUpdateRequestData>.self, from: data)
        let itemID = actionRequestData.data.id

        guard let loginItem = itemsInteractor.getItem(for: itemID, checkInTrash: false)?.asLoginItem else {
            throw ConnectError.missingItem
        }

        let encryptionPasswordKey: (ItemProtectionLevel) -> SymmetricKey? = { protectionLevel in
            let infoData: Data? = {
                switch protectionLevel {
                case .normal:
                    Keys.Connect.passwordTier3.data(using: .utf8)!
                case .confirm:
                    Keys.Connect.passwordTier2.data(using: .utf8)!
                case .topSecret:
                    nil
                }
            }()

            guard let infoData else {
                return nil
            }

            return HKDF<SHA256>.deriveKey(
                inputKeyMaterial: keys.sessionKey,
                salt: keys.hkdfSalt,
                info: infoData,
                outputByteCount: 32
            )
        }

        guard let protectionLevel = ItemProtectionLevel(intValue: actionRequestData.data.securityType) else {
            throw ConnectError.badData
        }

        let newPassword: String?
        if let newPasswordDataEnc = actionRequestData.data.passwordEnc, let encryptionKey = encryptionPasswordKey(protectionLevel), let newPasswordData = mainRepository.decrypt(newPasswordDataEnc, key: encryptionKey) {
            newPassword = String(data: newPasswordData, encoding: .utf8)
        } else {
            newPassword = nil
        }

        let changeRequst = LoginDataChangeRequest(
            name: actionRequestData.data.name,
            username: actionRequestData.data.username.map { .value($0) },
            password: actionRequestData.data.passwordMobile == true ? .generate : newPassword.map { .value($0) },
            notes: actionRequestData.data.notes,
            protectionLevel: protectionLevel,
            uris: actionRequestData.data.uris?.compactMap {
                guard let match = PasswordURI.Match(intValue: $0.matcher) else {
                    return nil
                }
                return PasswordURI(uri: $0.text, match: match)
            }
        )

        let accepted = await shouldPerfromAction(.changeRequest(.updateLogin(loginItem, changeRequst))).accepted

        guard accepted else {
            throw ConnectError.cancelled
        }

        guard let deviceID = mainRepository.deviceID else {
            throw ConnectError.missingDeviceId
        }

        let connectLogin = try await connectExportInteractor.prepareItemForConnectExport(
            id: itemID,
            deviceId: deviceID,
            secureFieldEncryptionKeyProvider: encryptionPasswordKey
        )
        let actionData = ConnectSchemaV1.ConnectActionItemData(
            type: .updateLogin,
            status: connectLogin.securityType == ItemProtectionLevel.topSecret.intValue ? .addedInT1 : .updated,
            login: connectLogin
        )
        return actionData
    }

    func handleDeleteLoginResponse(_ data: Data, keys: SessionKeys, shouldPerfromAction: (ConnectAction) async -> ConnectContinuation) async throws -> ConnectSchemaV1.ConnectActionItemData {
        let actionRequestData = try mainRepository.jsonDecoder.decode(ConnectSchemaV1.ConnectActionRequest<ConnectSchemaV1.ConnectActionPasswordRequestData>.self, from: data)
        let itemID = actionRequestData.data.loginId

        guard let item = itemsInteractor.getItem(for: itemID, checkInTrash: false) else {
            throw ConnectError.missingItem
        }

        let accepted = await shouldPerfromAction(.delete(item)).accepted

        guard accepted else {
            throw ConnectError.cancelled
        }

        return ConnectSchemaV1.ConnectActionItemData(type: .deleteLogin, status: .accept, login: nil)
    }
}
