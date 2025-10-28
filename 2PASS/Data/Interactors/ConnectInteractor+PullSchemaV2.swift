// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common
import CryptoKit
import Gzip

extension ConnectInteractor {

    // MARK: - Schema V2 Action Handlers

    func handleSifResponse(_ data: Data, keys: SessionKeys, shouldPerfromAction: (ConnectAction) async -> ConnectContinuation) async throws -> ConnectSchemaV2.ConnectActionResponseData<AnyCodable> {
        let actionRequestData = try mainRepository.jsonDecoder.decode(ConnectSchemaV2.ConnectActionSifRequest.self, from: data)

        let itemId = actionRequestData.data.itemId
        guard let item = itemsInteractor.getItem(for: itemId, checkInTrash: false) else {
            throw ConnectError.missingItem
        }

        guard let contentDict = try mainRepository.jsonDecoder.decode(AnyCodable.self, from: item.encodeContent(using: mainRepository.jsonEncoder)).value as? [String: Any] else {
            throw ConnectError.badData
        }

        let accepted = await shouldPerfromAction(.sifRequest(item)).accepted

        guard accepted else {
            throw ConnectError.cancelled
        }

        let encryptionPasswordKey = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: keys.sessionKey,
            salt: keys.hkdfSalt,
            info: Keys.Connect.itemTier2.data(using: .utf8)!,
            outputByteCount: 32
        )

        let encryptedContent = contentDict.reduce(into: [String: Any]()) { result, keyValue in
            if item.contentType.isSecureField(key: keyValue.key) {
                if let stringValue = keyValue.value as? String,
                   let data = Data(base64Encoded: stringValue),
                   let decryptedData = itemsInteractor.decryptData(data, isSecureField: true, protectionLevel: item.protectionLevel),
                   let nonce = mainRepository.generateRandom(byteCount: Config.Connect.secureFieldNonceByteCount),
                   let encyptedData = mainRepository.encrypt(decryptedData, key: encryptionPasswordKey, nonce: nonce)
                {
                    let key = keyValue.key.hasPrefix("s_") ? keyValue.key : "s_\(keyValue.key)"
                    result[key] = encyptedData.base64EncodedString()
                }
            }
        }

        return ConnectSchemaV2.ConnectActionResponseData(
            type: .sifRequest,
            status: .accept,
            expireInSeconds: 180,
            data: AnyCodable(encryptedContent),
            tags: nil
        )
    }

    func handleAddData(_ data: Data, keys: SessionKeys, shouldPerfromAction: (ConnectAction) async -> ConnectContinuation) async throws -> ConnectSchemaV2.ConnectActionResponseData<ConnectSchemaV2.ConnectItem> {
        let actionRequestData = try mainRepository.jsonDecoder.decode(ConnectSchemaV2.ConnectActionAddDataRequest.self, from: data)

        let contentType = ItemContentType(rawValue: actionRequestData.data.contentType)

        let encryptionNewPasswordKey = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: keys.sessionKey,
            salt: keys.hkdfSalt,
            info: Keys.Connect.newItem.data(using: .utf8)!,
            outputByteCount: 32
        )

        let itemChangeRequest: ItemChangeRequest

        switch contentType {
        case .login:
            guard let loginContent = try? mainRepository.jsonDecoder.decode(ConnectSchemaV2.ConnectActionAddLoginRequest.self, from: data) else {
                throw ConnectError.badData
            }

            var newPassword: String?
            if let newPasswordDataEnc = loginContent.data.content.password.value, let newPasswordData = mainRepository.decrypt(newPasswordDataEnc, key: encryptionNewPasswordKey) {
                newPassword = String(data: newPasswordData, encoding: .utf8)
            }

            let name = uriInteractor.extractDomain(from: loginContent.data.content.url) ?? loginContent.data.content.url

            itemChangeRequest = .addLogin(
                LoginDataChangeRequest(
                    name: name,
                    username: loginContent.data.content.username.action == .generate ? .generate : loginContent.data.content.username.value.map { .value($0) },
                    password: loginContent.data.content.password.action == .generate ? .generate : newPassword.map { .value($0) },
                    uris: [PasswordURI(uri: loginContent.data.content.url, match: .domain)]
                )
            )
        case .secureNote:
            throw ConnectError.unsuppotedContentType(ItemContentType.secureNote.rawValue)
        case .unknown(let contentType):
            throw ConnectError.unsuppotedContentType(contentType)
        }

        let (accepted, newItemId) = await shouldPerfromAction(.changeRequest(itemChangeRequest))

        guard accepted else {
            throw ConnectError.cancelled
        }

        guard let newItemId else {
            throw ConnectError.badData
        }

        let encryptionPasswordKey: (ItemProtectionLevel) -> SymmetricKey? = { protectionLevel in
            let infoData: Data? = {
                switch protectionLevel {
                case .normal:
                    Keys.Connect.itemTier3.data(using: .utf8)!
                case .confirm:
                    Keys.Connect.itemTier2.data(using: .utf8)!
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

        let connectItem = try await connectExportInteractor.prepareItemForConnectExport(
            id: newItemId,
            options: { _ in .allFields },
            secureFieldEncryptionKeyProvider: encryptionPasswordKey
        )

        let connectTags = try await connectExportInteractor.prepareTagsForConnectExport()

        return ConnectSchemaV2.ConnectActionResponseData(
            type: .addData,
            status: connectItem == nil ? .addedInT1 : .added,
            expireInSeconds: connectItem == nil ? nil : 180,
            data: connectItem,
            tags: connectTags
        )
    }

    func handleUpdateData(_ data: Data, keys: SessionKeys, shouldPerfromAction: (ConnectAction) async -> ConnectContinuation) async throws -> ConnectSchemaV2.ConnectActionResponseData<ConnectSchemaV2.ConnectItem> {
        let actionRequestData = try mainRepository.jsonDecoder.decode(ConnectSchemaV2.ConnectActionUpdateDataRequest.self, from: data)
        let itemId = actionRequestData.data.itemId

        let contentType = ItemContentType(rawValue: actionRequestData.data.contentType)

        guard let item = itemsInteractor.getItem(for: itemId, checkInTrash: false) else {
            throw ConnectError.missingItem
        }

        let encryptionPasswordKey: (ItemProtectionLevel) -> SymmetricKey? = { protectionLevel in
            let infoData: Data? = {
                switch protectionLevel {
                case .normal:
                    Keys.Connect.itemTier3.data(using: .utf8)!
                case .confirm:
                    Keys.Connect.itemTier2.data(using: .utf8)!
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

        let newProtectionLevel = actionRequestData.data.securityType.flatMap { ItemProtectionLevel(intValue: $0) }

        let itemChangeRequest: ItemChangeRequest

        switch contentType {
        case .login:
            guard let loginRequest = try? mainRepository.jsonDecoder.decode(ConnectSchemaV2.ConnectActionUpdateLoginRequest.self, from: data) else {
                throw ConnectError.badData
            }

            guard let loginItem = item.asLoginItem else {
                throw ConnectError.badData
            }

            let newPassword: String?
            if let newPasswordDataEnc = loginRequest.data.content.password?.value,
               let encryptionKey = encryptionPasswordKey(loginItem.protectionLevel),
                let newPasswordData = mainRepository.decrypt(newPasswordDataEnc, key: encryptionKey) {
                newPassword = String(data: newPasswordData, encoding: .utf8)
            } else {
                newPassword = nil
            }

            itemChangeRequest = .updateLogin(loginItem, LoginDataChangeRequest(
                name: loginRequest.data.content.name,
                username: loginRequest.data.content.username?.action == .generate ? .generate : loginRequest.data.content.username?.value.map { .value($0) },
                password: loginRequest.data.content.password?.action == .generate ? .generate : newPassword.map { .value($0) },
                notes: loginRequest.data.content.notes,
                protectionLevel: newProtectionLevel,
                uris: loginRequest.data.content.uris?.compactMap {
                    guard let match = PasswordURI.Match(intValue: $0.matcher) else {
                        return nil
                    }
                    return PasswordURI(uri: $0.text, match: match)
                },
                tags: loginRequest.data.tags
            ))
        case .secureNote:
            throw ConnectError.unsuppotedContentType(ItemContentType.secureNote.rawValue)
        case .unknown(let contentType):
            throw ConnectError.unsuppotedContentType(contentType)
        }

        let accepted = await shouldPerfromAction(.changeRequest(itemChangeRequest)).accepted

        guard accepted else {
            throw ConnectError.cancelled
        }

        let connectItem = try await connectExportInteractor.prepareItemForConnectExport(
            id: itemId,
            options: { item in
                if actionRequestData.data.sifFetched == true {
                    return .allFields
                }
                return item.protectionLevel == .normal ? .allFields : .includeUnencryptedFields
            },
            secureFieldEncryptionKeyProvider: encryptionPasswordKey
        )

        let connectTags = try await connectExportInteractor.prepareTagsForConnectExport()

        return ConnectSchemaV2.ConnectActionResponseData(
            type: .updateData,
            status: connectItem == nil ? .addedInT1 : .updated,
            expireInSeconds: connectItem == nil ? nil : 180,
            data: connectItem,
            tags: connectTags
        )
    }

    func handleDeleteData(_ data: Data, keys: SessionKeys, shouldPerfromAction: (ConnectAction) async -> ConnectContinuation) async throws -> ConnectSchemaV2.ConnectActionResponseData<ConnectActionEmptyResponseData> {
        let actionRequestData = try mainRepository.jsonDecoder.decode(ConnectSchemaV2.ConnectActionDeleteDataRequest.self, from: data)
        let itemId = actionRequestData.data.itemId

        guard let item = itemsInteractor.getItem(for: itemId, checkInTrash: false) else {
            throw ConnectError.missingItem
        }

        let accepted = await shouldPerfromAction(.delete(item)).accepted

        guard accepted else {
            throw ConnectError.cancelled
        }

        return ConnectSchemaV2.ConnectActionResponseData(
            type: .deleteData,
            status: .accept
        )
    }

    func handleSync(pullSession: ConnectPullWebSocketSession, encryptionDataKey: SymmetricKey, keys: SessionKeys, shouldPerfromAction: (ConnectAction) async -> ConnectContinuation) async throws {
        let accepted = await shouldPerfromAction(.sync).accepted

        guard accepted else {
            throw ConnectError.cancelled
        }

        let secureFieldsKey = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: keys.sessionKey,
            salt: keys.hkdfSalt,
            info: Keys.Connect.itemTier3.data(using:.utf8)!,
            outputByteCount: 32
        )

        let vaults = await connectExportInteractor.prepareVaultsForConnectExport(
            secureFieldEncryptionKeyProvider: { protectionLevel in
                switch protectionLevel {
                case .normal: secureFieldsKey
                case .confirm, .topSecret: nil
                }
            }
        )
        let vaultsData = try self.mainRepository.jsonEncoder.encode(vaults)

        let compressedVaults = try vaultsData.gzipped()
        let nonceD = mainRepository.generateRandom(byteCount: Config.Connect.nonceByteCount)!
        let gzipVaultsDataEnc = mainRepository.encrypt(compressedVaults, key: encryptionDataKey, nonce: nonceD)!

        let sha256Gzip = SHA256.hash(data: gzipVaultsDataEnc)

        let dataToSend = gzipVaultsDataEnc.base64EncodedString()
        let chunkSize = Config.Connect.chunkSize
        let chunkCount = (dataToSend.count + chunkSize - 1) / chunkSize

        let sync = ConnectSchemaV2.SyncData(
            type: .fullSync,
            status: .accept,
            totalChunks: chunkCount,
            totalSize: gzipVaultsDataEnc.count,
            sha256GzipVaultDataEnc: Data(sha256Gzip).base64EncodedString()
        )

        let responseData = try mainRepository.jsonEncoder.encode(sync)

        guard let nonceD = mainRepository.generateRandom(byteCount: Config.Connect.nonceByteCount) else {
            throw ConnectError.encryptionFailure
        }

        guard let dateEnc = mainRepository.encrypt(responseData, key: encryptionDataKey, nonce: nonceD) else {
            throw ConnectError.encryptionFailure
        }

        try await pullSession.sendPullActionResponse(dataEnc: dateEnc, isFullSync: true)

        for index in 0..<chunkCount {
            try await pullSession.sendChunk(
                index: index,
                chunkCount: chunkCount,
                chunkSize: chunkSize,
                dataToSend: dataToSend
            )
        }
    }
}
