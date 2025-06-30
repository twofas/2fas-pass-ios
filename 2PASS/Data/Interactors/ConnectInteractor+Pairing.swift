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
    
    private func performConnecting(for session: ConnectSession, using: ConnectWebSocketSession, progress: @escaping (Float) -> Void, onReceiveBrowserInfo: @escaping (WebBrowser) -> Void) async throws {
        let webBrowser = await webBrowsersInteractor.getWebBrowser(publicKey: session.pkPersBeHex)

        let keys = try createKeys(pkEpheBeHex: session.pkEpheBeHex)
        
        guard let deviceID = mainRepository.deviceID else {
            throw ConnectError.missingDeviceId
        }
        
        do {
            let helloRequest = ConnectRequests.Hello(payload: .init(
                deviceId: deviceID.uuidString,
                deviceName: mainRepository.deviceName,
                deviceOs: "ios"
            ))
            
            let helloResponse = try await using.send(helloRequest)
            
            Log("Connect - Hello response received", module: .connect, severity: .info)
            
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
            
            let challengeRequest = ConnectRequests.Challenge(payload: .init(
                pkEpheMa: keys.publicKey.derRepresentation.base64EncodedString(),
                hkdfSalt: keys.hkdfSalt.base64EncodedString())
            )
            
            let challengeResponse = try await using.send(challengeRequest)
            
            Log("Connect - Challenge response received", module: .connect, severity: .info)
            
            progress(0.4)
            
            do {
                try verifySalt(challengeResponse.hkdfSaltEnc, keys: keys)
            } catch {
                throw ConnectError.saltVerificationFailed
            }
            
            let encryptionDataKey = HKDF<SHA256>.deriveKey(
                inputKeyMaterial: keys.sessionKey,
                salt: keys.hkdfSalt,
                info: Keys.Connect.data.data(using: .utf8)!,
                outputByteCount: 32
            )
            let encryptionPassKey = HKDF<SHA256>.deriveKey(
                inputKeyMaterial: keys.sessionKey,
                salt: keys.hkdfSalt,
                info: Keys.Connect.passwordTier3.data(using:.utf8)!,
                outputByteCount: 32
            )
            
            let passwordsData = try await connectExportInteractor.preparePasswordsForConnectExport(encryptPasswordKey: encryptionPassKey, deviceId: deviceID)
            let tagsData = try await connectExportInteractor.prepareTagsForConnectExport()
            
            try Task.checkCancellation()
            
            progress(0.5)
            
            let compressedPasswords = try passwordsData.gzipped()
            let compressedTags = try tagsData.gzipped()
            let vault = ConnectVault(
                logins: compressedPasswords.base64EncodedString(),
                tags: compressedTags.base64EncodedString()
            )
            let vaultData = try mainRepository.jsonEncoder.encode(vault)
            
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
                  let gzipVaultDataEnc = mainRepository.encrypt(vaultData, key: encryptionDataKey, nonce: nonceD) else {
                throw ConnectError.encryptionFailure
            }
            
            let expirationDateEnc: Data? = {
                if let expirationDate = paymentStatusInteractor.plan.expirationDate, let expirationTimestamp = "\(expirationDate.exportTimestamp))".data(using: .utf8) {
                    return mainRepository.encrypt(expirationTimestamp, key: encryptionDataKey, nonce: nonceE)
                } else {
                    return nil
                }
            }()
            
            let sha256Gzip = SHA256.hash(data: gzipVaultDataEnc)
            
            let dataToSend = gzipVaultDataEnc.base64EncodedString()
            let chunkSize = Config.Connect.chunkSize
            let chunkCount = (dataToSend.count + chunkSize - 1) / chunkSize
            
            let initTransferRequest = ConnectRequests.InitTransfer(payload: .init(
                totalChunks: chunkCount,
                totalSize: gzipVaultDataEnc.count,
                sha256GzipVaultDataEnc: Data(sha256Gzip).base64EncodedString(),
                fcmTokenEnc: fcmTokenEnc.base64EncodedString(),
                newSessionIdEnc: newSessionIdEnc.base64EncodedString(),
                expirationDateEnc: expirationDateEnc?.base64EncodedString()
            ))
            
            try await using.send(initTransferRequest)
            
            Log("Connect - Init transfer response received", module: .connect, severity: .info)
            
            progress(0.6)
            
            for index in 0..<chunkCount {
                let startChunk = index * chunkSize
                let endChunk = min((index+1) * chunkSize, dataToSend.count)
                let chunkData = dataToSend[startChunk..<endChunk]
                
                if index == chunkCount - 1 {
                    let transferRequest = ConnectRequests.TransferLastChunk(payload: .init(
                        chunkIndex: index,
                        chunkSize: chunkData.count,
                        chunkData: chunkData
                    ))
                    _ = try await using.send(transferRequest)
                } else {
                    let transferRequest = ConnectRequests.TransferChunk(payload: .init(
                        chunkIndex: index,
                        chunkSize: chunkData.count,
                        chunkData: chunkData
                    ))
                    _ = try await using.send(transferRequest)
                }
                
                Log("Connect - Transfer chunk response received", module: .connect, severity: .info)
                
                progress(0.6 + 0.3 * Float(index) / Float(chunkCount))
            }
            
            progress(0.9)
            
            let closeRequest = ConnectRequests.CloseWithSuccess()
            try await using.send(closeRequest)
            
            Log("Connect - Close with success response received", module: .connect, severity: .info)
            
            progress(1.0)
            
        } catch URLError.cancelled {
            throw ConnectError.cancelled
        } catch ConnectWebSocketError.webSocketClosed {
            throw ConnectError.webSocketClosed
        } catch is CancellationError {
            throw ConnectError.cancelled
        } catch {
            do {
                let closeWithError = ConnectRequests.CloseWithError(payload: .init(error: error))
                try await using.send(closeWithError)
            } catch {
                Log("Connect - Error while closing with error browser extension: \(error)", module: .connect)
            }
            
            Log("Connect - Error while connecting with browser extension: \(error)", module: .connect)
            throw error
        }
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

private struct ConnectVault: Codable {
    public let logins: String
    public let tags: String
}
