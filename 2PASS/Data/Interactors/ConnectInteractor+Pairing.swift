// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common
import CryptoKit

extension ConnectInteractor {
    
    @MainActor
    func isKnownBrowser(from session: ConnectSession) -> Bool {
        webBrowsersInteractor.contains(publicKey: session.pkPersBeHex)
    }
    
    func connect(with session: ConnectSession, progress: @escaping (Float) -> Void, onReceiveBrowserInfo: @escaping (WebBrowser) -> Void) async throws {
        let webSocketSession = ConnectWebSocketSession(
            baseURL: Config.Connect.baseURL,
            sessionId: session.sessionId,
            deviceName: mainRepository.deviceName,
            appVersion: mainRepository.currentAppVersion
        )
        
        try webSocketSession.validateSchemeVersion(session.version.rawValue)
        
        webSocketSession.start()
        
        let continuationStorage = CheckedContinuationThreadSafeStorage<Void>()
        
        let connectingTask = Task {
            do {
                try await performConnecting(
                    for: session,
                    using: webSocketSession,
                    progress: progress,
                    onReceiveBrowserInfo: onReceiveBrowserInfo
                )
                await continuationStorage.finish()
            } catch {
                await continuationStorage.finish(throwing: error)
            }
        }
        
        webSocketSession.onClose {
            connectingTask.cancel()
            
            Task {
                await continuationStorage.finish(throwing: ConnectError.webSocketClosed)
            }
        }
        
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                Task {
                    await continuationStorage.set(continuation)
                }
            }
        } onCancel: {
            connectingTask.cancel()
        }
    }
    
    private func performConnecting(
        for session: ConnectSession,
        using webSocketSession: ConnectWebSocketSession,
        progress: @escaping (Float) -> Void,
        onReceiveBrowserInfo: @escaping (WebBrowser) -> Void
    ) async throws {
        let webBrowser = await webBrowsersInteractor.getWebBrowser(publicKey: session.pkPersBeHex)
        let keys = try createKeys(pkEpheBeHex: session.pkEpheBeHex)
        
        guard let deviceID = mainRepository.deviceID else {
            throw ConnectError.missingDeviceId
        }
        
        let pairingSession = ConnectPairingWebSocketSession(
            schemeVersion: session.version,
            webSocketSession: webSocketSession
        )
        
        do {
            let helloResponse = try await pairingSession.helloHandshake(
                deviceID: deviceID,
                deviceName: mainRepository.deviceName,
                deviceType: .init(mainRepository.deviceType)
            )
            
            progress(0.25)
            
            guard let newSessionId = mainRepository.generateRandom(byteCount: Config.Connect.sessionIdByteCount) else {
                throw ConnectError.encryptionFailure
            }
            
            let browser = await saveConnectionWithWebBrowser(
                webBrowser,
                using: session,
                response: helloResponse,
                nextSessionId: newSessionId
            )
            onReceiveBrowserInfo(browser)
            
            let challengeResponse = try await pairingSession.challengeExchange(keys: keys)
            
            do {
                try verifySalt(challengeResponse.hkdfSaltEnc, keys: keys)
            } catch {
                throw ConnectError.saltVerificationFailed
            }
            
            progress(0.4)
            
            let encryptionDataKey = deriveEncryptionDataKey(from: keys)
            
            let vaultsData = try await prepareVaultsData(
                session: session,
                deviceID: deviceID,
                keys: keys
            )
            
            progress(0.5)
            
            let encryptedData = try encryptTransferData(
                vaultsData: vaultsData,
                newSessionId: newSessionId,
                encryptionDataKey: encryptionDataKey
            )
            
            try await pairingSession.initTransfer(encryptedData: encryptedData)
            
            progress(0.6)
            
            let dataToSend = encryptedData.gzipVaultsDataEnc.base64EncodedString()
            let chunkSize = Config.Connect.chunkSize
            let chunkCount = (dataToSend.count + chunkSize - 1) / chunkSize
            
            for index in 0..<chunkCount {
                try await pairingSession.sendChunk(
                    index: index,
                    chunkCount: chunkCount,
                    chunkSize: chunkSize,
                    dataToSend: dataToSend
                )
                progress(0.6 + 0.3 * Float(index) / Float(chunkCount))
            }
            
            progress(0.9)
            
            try await pairingSession.closeConnectionWithSuccess()
            
            progress(1.0)
            
        } catch URLError.cancelled {
            throw ConnectError.cancelled
        } catch ConnectWebSocketError.webSocketClosed {
            throw ConnectError.webSocketClosed
        } catch is CancellationError {
            throw ConnectError.cancelled
        } catch {
            await pairingSession.closeConnection(with: error)
            throw error
        }
    }

    // MARK: - Vaults Data Preparation

    private func prepareVaultsData(
        session: ConnectSession,
        deviceID: UUID,
        keys: SessionKeys
    ) async throws -> Data {
        switch session.version {
        case .v1:
            return try await prepareV1VaultsData(deviceID: deviceID, keys: keys)
        default:
            return try await prepareV2VaultsData(keys: keys)
        }
    }

    private func prepareV1VaultsData(
        deviceID: UUID,
        keys: SessionKeys
    ) async throws -> Data {
        let passwordEncryptionKey = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: keys.sessionKey,
            salt: keys.hkdfSalt,
            info: Keys.Connect.passwordTier3.data(using:.utf8)!,
            outputByteCount: 32
        )

        let tags = try await connectExportInteractor.prepareTagsForConnectExport()
        let items = try await connectExportInteractor.prepareItemsForConnectExport(
            deviceId: deviceID,
            secureFieldEncryptionKeyProvider: { protectionLevel in
                switch protectionLevel {
                case .normal: passwordEncryptionKey
                default: nil
                }
            }
        )

        let itemsData = try mainRepository.jsonEncoder.encode(items)
        let tagsData = try mainRepository.jsonEncoder.encode(tags)

        try Task.checkCancellation()

        let compressedItems = try itemsData.gzipped()
        let compressedTags = try tagsData.gzipped()
        let vault = ConnectSchemaV1.ConnectVault(
            logins: compressedItems.base64EncodedString(),
            tags: compressedTags.base64EncodedString()
        )
        return try mainRepository.jsonEncoder.encode(vault)
    }

    private func prepareV2VaultsData(keys: SessionKeys) async throws -> Data {
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
                default: nil
                }
            }
        )

        let vaultsData = try mainRepository.jsonEncoder.encode(vaults)

        try Task.checkCancellation()

        return try vaultsData.gzipped()
    }

    // MARK: - Data Encryption

    private func encryptTransferData(
        vaultsData: Data,
        newSessionId: Data,
        encryptionDataKey: SymmetricKey
    ) throws -> ConnectPairingWebSocketSession.EncryptedTransferData {
        guard let nonceS = mainRepository.generateRandom(byteCount: Config.Connect.nonceByteCount),
              let nonceD = mainRepository.generateRandom(byteCount: Config.Connect.nonceByteCount),
              let nonceT = mainRepository.generateRandom(byteCount: Config.Connect.nonceByteCount),
              let nonceE = mainRepository.generateRandom(byteCount: Config.Connect.nonceByteCount) else {
            throw ConnectError.encryptionFailure
        }

        let fcmToken = mainRepository.pushNotificationToken ?? ""

        guard let newSessionIdEnc = mainRepository.encrypt(newSessionId, key: encryptionDataKey, nonce: nonceS),
              let fcmTokenData = fcmToken.data(using: .utf8),
              let fcmTokenEnc = mainRepository.encrypt(fcmTokenData, key: encryptionDataKey, nonce: nonceT),
              let gzipVaultsDataEnc = mainRepository.encrypt(vaultsData, key: encryptionDataKey, nonce: nonceD) else {
            throw ConnectError.encryptionFailure
        }

        let expirationDateEnc: Data? = {
            if let expirationDate = paymentStatusInteractor.plan.expirationDate,
               let expirationTimestamp = "\(expirationDate.exportTimestamp))".data(using: .utf8) {
                return mainRepository.encrypt(expirationTimestamp, key: encryptionDataKey, nonce: nonceE)
            } else {
                return nil
            }
        }()

        let sha256Gzip = SHA256.hash(data: gzipVaultsDataEnc)

        return .init(
            newSessionIdEnc: newSessionIdEnc,
            fcmTokenEnc: fcmTokenEnc,
            gzipVaultsDataEnc: gzipVaultsDataEnc,
            expirationDateEnc: expirationDateEnc,
            sha256Gzip: sha256Gzip
        )
    }

    @MainActor
    private func saveConnectionWithWebBrowser(
        _ webBrowser: WebBrowser?,
        using session: ConnectSession,
        response: ConnectRequests.Hello.ResponsePayload,
        nextSessionId: Data
    ) -> WebBrowser {
        if var webBrowser {
            webBrowser.name = response.browserName
            webBrowser.version = response.browserVersion
            webBrowser.extName = response.browserExtName
            webBrowser.lastConnectionDate = mainRepository.currentDate
            webBrowser.nextSessionID = nextSessionId
            
            webBrowsersInteractor.update(webBrowser)
            
            return webBrowser
        } else {
            let webBrowser = WebBrowser(
                id: UUID(),
                publicKey: session.pkPersBeHex,
                name: response.browserName,
                version: response.browserVersion,
                extName: response.browserExtName,
                firstConnectionDate: mainRepository.currentDate,
                lastConnectionDate: mainRepository.currentDate,
                nextSessionID: nextSessionId
            )
            webBrowsersInteractor.insert(webBrowser)
            
            return webBrowser
        }
    }
}
