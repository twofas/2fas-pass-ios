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
        let item = await MainActor.run {
            itemsInteractor.getItem(for: itemId, checkInTrash: false)
        }

        guard let item else {
            throw ConnectError.missingItem
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

        let encryptedContent: [String: Any]
        do {
            encryptedContent = try connectExportInteractor.prepareSecureFieldsForConnectExport(
                item: item,
                secureFieldEncryptionKey: encryptionPasswordKey
            )
        } catch {
            throw ConnectError.badData
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

        let encryptionNewItemKey = HKDF<SHA256>.deriveKey(
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
            if let newPasswordDataEnc = loginContent.data.content.password.value, let newPasswordData = mainRepository.decrypt(newPasswordDataEnc, key: encryptionNewItemKey) {
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
            guard let secureNoteContent = try? mainRepository.jsonDecoder.decode(ConnectSchemaV2.ConnectActionAddSecureNoteRequest.self, from: data) else {
                throw ConnectError.badData
            }

            var newText: String?
            if let newTextData = mainRepository.decrypt(secureNoteContent.data.content.text, key: encryptionNewItemKey) {
                newText = String(data: newTextData, encoding: .utf8)
            }

            itemChangeRequest = .addSecureNote(
                SecureNoteDataChangeRequest(
                    name: secureNoteContent.data.content.name,
                    text: newText
                )
            )
        case .paymentCard:
            guard let paymentCardContent = try? mainRepository.jsonDecoder.decode(ConnectSchemaV2.ConnectActionAddCardRequest.self, from: data) else {
                throw ConnectError.badData
            }

            var newCardNumber: String?
            if let cardNumberDataEnc = paymentCardContent.data.content.cardNumber,
               let cardNumberData = mainRepository.decrypt(cardNumberDataEnc, key: encryptionNewItemKey) {
                newCardNumber = String(data: cardNumberData, encoding: .utf8)
            }

            var newExpirationDate: String?
            if let expirationDateDataEnc = paymentCardContent.data.content.expirationDate,
               let expirationDateData = mainRepository.decrypt(expirationDateDataEnc, key: encryptionNewItemKey) {
                newExpirationDate = String(data: expirationDateData, encoding: .utf8)
            }

            var newSecurityCode: String?
            if let securityCodeDataEnc = paymentCardContent.data.content.securityCode,
               let securityCodeData = mainRepository.decrypt(securityCodeDataEnc, key: encryptionNewItemKey) {
                newSecurityCode = String(data: securityCodeData, encoding: .utf8)
            }

            itemChangeRequest = .addPaymentCard(
                PaymentCardDataChangeRequest(
                    name: paymentCardContent.data.content.name,
                    cardHolder: paymentCardContent.data.content.cardHolder,
                    cardNumber: newCardNumber,
                    expirationDate: newExpirationDate,
                    securityCode: newSecurityCode,
                    notes: paymentCardContent.data.content.notes
                )
            )
        case .wifi:
            guard let wifiContent = try? mainRepository.jsonDecoder.decode(ConnectSchemaV2.ConnectActionAddWiFiRequest.self, from: data) else {
                throw ConnectError.badData
            }

            var newPassword: String?
            if let passwordDataEnc = wifiContent.data.content.password,
               let passwordData = mainRepository.decrypt(passwordDataEnc, key: encryptionNewItemKey) {
                newPassword = String(data: passwordData, encoding: .utf8)
            }

            itemChangeRequest = .addWiFi(
                WiFiDataChangeRequest(
                    name: wifiContent.data.content.name,
                    ssid: wifiContent.data.content.ssid,
                    password: newPassword,
                    notes: wifiContent.data.content.notes,
                    securityType: wifiContent.data.content.securityType,
                    hidden: wifiContent.data.content.hidden
                )
            )
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

        let item = await MainActor.run {
            itemsInteractor.getItem(for: itemId, checkInTrash: false)
        }

        guard let item else {
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
                        
            if let newPasswordDataEnc = loginRequest.data.content.password?.value {
                if newPasswordDataEnc.isEmpty {
                    newPassword = ""
                } else if let encryptionKey = encryptionPasswordKey(loginItem.protectionLevel),
                          let newPasswordData = mainRepository.decrypt(newPasswordDataEnc, key: encryptionKey) {
                    newPassword = String(data: newPasswordData, encoding: .utf8)
                } else {
                    newPassword = nil
                }
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
            guard let secureNoteRequest = try? mainRepository.jsonDecoder.decode(ConnectSchemaV2.ConnectActionUpdateSecureNoteRequest.self, from: data) else {
                throw ConnectError.badData
            }

            guard let secureNoteItem = item.asSecureNote else {
                throw ConnectError.badData
            }

            let newText: String?

            if let newTextDataEnc = secureNoteRequest.data.content.text {
                if newTextDataEnc.isEmpty {
                    newText = ""
                } else if let encryptionKey = encryptionPasswordKey(secureNoteItem.protectionLevel),
                          let newTextData = mainRepository.decrypt(newTextDataEnc, key: encryptionKey) {
                    newText = String(data: newTextData, encoding: .utf8)
                } else {
                    newText = nil
                }
            } else {
                newText = nil
            }

            itemChangeRequest = .updateSecureNote(secureNoteItem, SecureNoteDataChangeRequest(
                name: secureNoteRequest.data.content.name,
                text: newText,
                additionalInfo: secureNoteRequest.data.content.additionalInfo,
                protectionLevel: newProtectionLevel,
                tags: secureNoteRequest.data.tags
            ))
        case .paymentCard:
            guard let paymentCardRequest = try? mainRepository.jsonDecoder.decode(ConnectSchemaV2.ConnectActionUpdateCardRequest.self, from: data) else {
                throw ConnectError.badData
            }

            guard let paymentCardItem = item.asPaymentCard else {
                throw ConnectError.badData
            }

            let newCardNumber: String?
            if let cardNumberDataEnc = paymentCardRequest.data.content.cardNumber {
                if cardNumberDataEnc.isEmpty {
                    newCardNumber = ""
                } else if let encryptionKey = encryptionPasswordKey(paymentCardItem.protectionLevel),
                          let cardNumberData = mainRepository.decrypt(cardNumberDataEnc, key: encryptionKey) {
                    newCardNumber = String(data: cardNumberData, encoding: .utf8)
                } else {
                    newCardNumber = nil
                }
            } else {
                newCardNumber = nil
            }

            let newExpirationDate: String?
            if let expirationDateDataEnc = paymentCardRequest.data.content.expirationDate {
                if expirationDateDataEnc.isEmpty {
                    newExpirationDate = ""
                } else if let encryptionKey = encryptionPasswordKey(paymentCardItem.protectionLevel),
                          let expirationDateData = mainRepository.decrypt(expirationDateDataEnc, key: encryptionKey) {
                    newExpirationDate = String(data: expirationDateData, encoding: .utf8)
                } else {
                    newExpirationDate = nil
                }
            } else {
                newExpirationDate = nil
            }

            let newSecurityCode: String?
            if let securityCodeDataEnc = paymentCardRequest.data.content.securityCode {
                if securityCodeDataEnc.isEmpty {
                    newSecurityCode = ""
                } else if let encryptionKey = encryptionPasswordKey(paymentCardItem.protectionLevel),
                          let securityCodeData = mainRepository.decrypt(securityCodeDataEnc, key: encryptionKey) {
                    newSecurityCode = String(data: securityCodeData, encoding: .utf8)
                } else {
                    newSecurityCode = nil
                }
            } else {
                newSecurityCode = nil
            }

            itemChangeRequest = .updatePaymentCard(paymentCardItem, PaymentCardDataChangeRequest(
                name: paymentCardRequest.data.content.name,
                cardHolder: paymentCardRequest.data.content.cardHolder,
                cardNumber: newCardNumber,
                expirationDate: newExpirationDate,
                securityCode: newSecurityCode,
                notes: paymentCardRequest.data.content.notes,
                protectionLevel: newProtectionLevel,
                tags: paymentCardRequest.data.tags
            ))
        case .wifi:
            guard let wifiRequest = try? mainRepository.jsonDecoder.decode(ConnectSchemaV2.ConnectActionUpdateWiFiRequest.self, from: data) else {
                throw ConnectError.badData
            }

            guard let wifiItem = item.asWiFi else {
                throw ConnectError.badData
            }

            let newPassword: String?
            if let passwordDataEnc = wifiRequest.data.content.password {
                if passwordDataEnc.isEmpty {
                    newPassword = ""
                } else if let encryptionKey = encryptionPasswordKey(wifiItem.protectionLevel),
                          let passwordData = mainRepository.decrypt(passwordDataEnc, key: encryptionKey) {
                    newPassword = String(data: passwordData, encoding: .utf8)
                } else {
                    newPassword = nil
                }
            } else {
                newPassword = nil
            }

            itemChangeRequest = .updateWiFi(wifiItem, WiFiDataChangeRequest(
                name: wifiRequest.data.content.name,
                ssid: wifiRequest.data.content.ssid,
                password: newPassword,
                notes: wifiRequest.data.content.notes,
                securityType: wifiRequest.data.content.securityType,
                hidden: wifiRequest.data.content.hidden,
                protectionLevel: newProtectionLevel,
                tags: wifiRequest.data.tags
            ))
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

        let item = await MainActor.run {
            itemsInteractor.getItem(for: itemId, checkInTrash: false)
        }

        guard let item else {
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
