// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common
import CryptoKit

extension ConnectInteractor {
 
    func validateNotification(_ notification: AppNotification) async -> Bool {
        guard let webBrowser = await webBrowser(for: notification) else {
            return false
        }
        
        guard let pkPersBe = Data(base64Encoded: notification.data.pkPersBe) else {
            return false
        }
                
        guard let sessionId = webBrowser.nextSessionID, let deviceId = mainRepository.deviceID else {
            return false
        }
        
        guard let pkEpheBe = Data(base64Encoded: notification.data.pkEpheBe) else {
            return false
        }
        let pkEpheBeHex = pkEpheBe.toHEXString()
    
        let inputString = "\(sessionId.toHEXString())\(deviceId)\(pkEpheBeHex)\(notification.data.timestamp)".lowercased()
            
        guard let data = inputString.data(using: .utf8) else {
            return false
        }
            
        let key = pkPersBe
        guard let signature = Data(base64Encoded: notification.data.sigPush) else {
            return false
        }
        
        do {
            let publicKey = try P256.Signing.PublicKey(compressedRepresentation: key)
            let signatureECDSA = try P256.Signing.ECDSASignature(rawRepresentation: signature)
            return publicKey.isValidSignature(signatureECDSA, for: data)
        } catch {
            Log("Notification has wrong signature", module: .connect, severity: .error)
            return false
        }
    }
    
    func connect(
        for notification: AppNotification,
        progress: @escaping (Float) -> Void,
        onReceiveBrowserInfo: @escaping (WebBrowser) -> Void,
        shouldPerfromAction: @escaping (ConnectAction) async -> ConnectContinuation
    ) async throws {
        guard let pkPersBe = Data(base64Encoded: notification.data.pkPersBe) else {
            throw ConnectError.badNotificationData
        }
        let pkPersBeHex = pkPersBe.toHEXString()
        
        guard let pkEpheBe = Data(base64Encoded: notification.data.pkEpheBe) else {
            throw ConnectError.badNotificationData
        }
        let pkEpheBeHex = pkEpheBe.toHEXString()
        
        guard let webBrowser = await webBrowsersInteractor.getWebBrowser(publicKey: pkPersBeHex) else {
            throw ConnectError.noWebBrowserForNotification
        }
        
        onReceiveBrowserInfo(webBrowser)
        
        guard let sessionId = webBrowser.nextSessionID else {
            throw ConnectError.missingSessionId
        }
        
        let keys = try createKeys(pkEpheBeHex: pkEpheBeHex)
        
        let session = ConnectWebSocketSession(
            baseURL: Config.Connect.baseURL,
            sessionId: sessionId.toHEXString(),
            deviceName: mainRepository.deviceName,
            appVersion: mainRepository.currentAppVersion
        )
        
        let continuationStorage = CheckedContinuationThreadSafeStorage<Void>()
        
        let connectingTask = Task {
            do {
                try await self.performPullConnecting(
                    using: session,
                    keys: keys,
                    webBrowser: webBrowser,
                    progress: progress,
                    shouldPerfromAction: shouldPerfromAction
                )
                await continuationStorage.finish()
            } catch {
                await continuationStorage.finish(throwing: error)
            }
        }
        
        session.onClose {
            connectingTask.cancel()
            
            Task {
                await continuationStorage.finish(throwing: ConnectError.webSocketClosed)
            }
        }
        
        session.start()
        
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
    
    private func performPullConnecting(
        using webSocketSession: ConnectWebSocketSession,
        keys: SessionKeys,
        webBrowser: WebBrowser,
        progress: (Float) -> Void,
        shouldPerfromAction: (ConnectAction) async -> ConnectContinuation) async throws {
            guard let deviceId = mainRepository.deviceID else {
                throw ConnectError.missingDeviceId
            }
            
            do {
                let helloRequest = ConnectRequests.Hello(payload: .init(
                    deviceId: deviceId.uuidString,
                    deviceName: mainRepository.deviceName,
                    deviceOs: "ios"
                ))
                
                _ = try await webSocketSession.send(helloRequest)
                
                Log("Connect - Hello response received", module: .connect, severity: .info)
                
                progress(0.25)
                
                let challengeRequest = ConnectRequests.Challenge(payload: .init(
                    pkEpheMa: keys.publicKey.derRepresentation.base64EncodedString(),
                    hkdfSalt: keys.hkdfSalt.base64EncodedString())
                )
                
                let challengeResponse = try await webSocketSession.send(challengeRequest)
                
                Log("Connect - Challenge response received", module: .connect, severity: .info)
                
                progress(0.4)
                
                do {
                    try verifySalt(challengeResponse.hkdfSaltEnc, keys: keys)
                } catch {
                    throw ConnectError.saltVerificationFailed
                }
                
                guard let newSessionId = mainRepository.generateRandom(byteCount: Config.Connect.sessionIdByteCount),
                      let nonceS = mainRepository.generateRandom(byteCount: Config.Connect.nonceByteCount) else {
                    throw ConnectError.encryptionFailure
                }
                
                let encryptionDataKey = HKDF<SHA256>.deriveKey(
                    inputKeyMaterial: keys.sessionKey,
                    salt: keys.hkdfSalt,
                    info: Keys.Connect.data.data(using: .utf8)!,
                    outputByteCount: 32
                )
                
                guard let newSessionIdEnc = mainRepository.encrypt(newSessionId, key: encryptionDataKey, nonce: nonceS) else {
                    throw ConnectError.encryptionFailure
                }
                
                let pullRequest = ConnectRequests.Pull(payload: .init(newSessionIdEnc: newSessionIdEnc))
                let pullResponse = try await webSocketSession.send(pullRequest)
                
                Log("Connect - Pull action received", module: .connect, severity: .info)
                
                progress(0.6)
                
                guard let decrypted = mainRepository.decrypt(pullResponse.dataEnc, key: encryptionDataKey) else {
                    throw ConnectError.decryptionFailure
                }
                
                let actionRequestType = try mainRepository.jsonDecoder.decode(ConnectActioRequestType.self, from: decrypted)
                
                var isCancelled = false
                
                do {
                    let response: (any Encodable)

                    switch actionRequestType.type {
                    case .passwordRequest:
                        response = try await handlePasswordRequestResponse(decrypted, keys: keys, shouldPerfromAction: shouldPerfromAction)
                    case .newLogin:
                        response = try await handleNewLoginResponse(decrypted, keys: keys, shouldPerfromAction: shouldPerfromAction)
                    case .updateLogin:
                        response = try await handleUpdateLoginResponse(decrypted, keys: keys, shouldPerfromAction: shouldPerfromAction)
                    case .deleteLogin:
                        response = try await handleDeleteLoginResponse(decrypted, keys: keys, shouldPerfromAction: shouldPerfromAction)
                    }
                    
                    try Task.checkCancellation()
                    
                    let responseData = try mainRepository.jsonEncoder.encode(response)
                    
                    guard let nonceD = mainRepository.generateRandom(byteCount: Config.Connect.nonceByteCount) else {
                        throw ConnectError.encryptionFailure
                    }
                    
                    guard let dateEnc = mainRepository.encrypt(responseData, key: encryptionDataKey, nonce: nonceD) else {
                        throw ConnectError.encryptionFailure
                    }
                    
                    let pullActionRequest = ConnectRequests.PullAction(payload: .init(dataEnc: dateEnc))
                    try await webSocketSession.send(pullActionRequest)
                    
                    Log("Connect - Pull action response sended", module: .connect, severity: .info)
                    
                } catch ConnectError.cancelled {
                    isCancelled = true
                    
                    try await sendPullActionCancel(
                        using: webSocketSession,
                        actionType: actionRequestType.type,
                        encryptionDataKey: encryptionDataKey
                    )
                    
                    Log("Connect - Pull action cancel sended", module: .connect, severity: .info)
                    
                } catch {
                    throw error
                }
                
                progress(0.9)
                
                var webBrowser = webBrowser
                webBrowser.nextSessionID = newSessionId
                await webBrowsersInteractor.update(webBrowser)
                
                let successRequest = ConnectRequests.CloseWithSuccess()
                try await webSocketSession.send(successRequest)
                
                Log("Connect - Close with success response received", module: .connect, severity: .info)
                
                progress(1.0)
                
                if isCancelled {
                    throw ConnectError.cancelled
                }
                
            } catch URLError.cancelled {
                throw ConnectError.cancelled
            } catch is CancellationError {
                throw ConnectError.cancelled
            } catch ConnectWebSocketError.webSocketClosed {
                throw ConnectError.webSocketClosed
            } catch {
                do {
                    let closeWithError = ConnectRequests.CloseWithError(payload: .init(error: error))
                    try await webSocketSession.send(closeWithError)
                } catch {
                    Log("Connect - Error while closing with error browser extension: \(error)", module: .connect)
                }
                
                Log("Connect - Error while connecting with browser extension: \(error)", module: .connect)
                throw error
            }
    }
    
    private func sendPullActionCancel(using webSocketSession: ConnectWebSocketSession, actionType: ConnectActionType, encryptionDataKey: SymmetricKey) async throws {
        guard let nonceD = mainRepository.generateRandom(byteCount: Config.Connect.nonceByteCount) else {
            throw ConnectError.encryptionFailure
        }
        
        let actionData = ConnectActionItemData(
            type: actionType,
            status: .cancel,
            login: nil
        )
        
        let jsonData = try mainRepository.jsonEncoder.encode(actionData)
        
        guard let dateEnc = mainRepository.encrypt(jsonData, key: encryptionDataKey, nonce: nonceD) else {
            return
        }
        
        let pullActionRequest = ConnectRequests.PullAction(payload: .init(dataEnc: dateEnc))
        try await webSocketSession.send(pullActionRequest)
    }
    
    private func handleNewLoginResponse(_ data: Data, keys: SessionKeys, shouldPerfromAction: (ConnectAction) async -> ConnectContinuation) async throws -> ConnectActionItemData {
        let actionRequestData = try mainRepository.jsonDecoder.decode(ConnectActionRequest<ConnectActionAddRequestData>.self, from: data)
        
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
        
        let changeRequst = PasswordDataChangeRequest(
            name: name,
            username: actionRequestData.data.username,
            password: actionRequestData.data.usernamePasswordMobile ? .generateNewPassword : newPassword.map { .value($0) },
            uris: [PasswordURI(uri: actionRequestData.data.url, match: .domain)]
        )
        
        let (accepted, newPasswordId) = await shouldPerfromAction(.add(changeRequst))
        
        guard accepted else {
            throw ConnectError.cancelled
        }
        
        guard let newPasswordId else {
            throw ConnectError.badData
        }
        
        let encryptionPasswordKey: (PasswordProtectionLevel) -> SymmetricKey? = { protectionLevel in
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
        
        let connectLogin = try await connectExportInteractor.preparePasswordForConnectExport(
            id: newPasswordId,
            encryptPasswordKey: encryptionPasswordKey,
            deviceId: deviceID
        )
        let actionData = ConnectActionItemData(
            type: .newLogin,
            status: connectLogin.securityType == PasswordProtectionLevel.topSecret.intValue ? .addedInT1 : .added,
            login: connectLogin.securityType == PasswordProtectionLevel.topSecret.intValue ? nil : connectLogin
        )
        return actionData
    }
    
    private func handlePasswordRequestResponse(_ data: Data, keys: SessionKeys, shouldPerfromAction: (ConnectAction) async -> ConnectContinuation) async throws -> ConnectActionPasswordData {
        let actionRequestData = try mainRepository.jsonDecoder.decode(ConnectActionRequest<ConnectActionPasswordRequestData>.self, from: data)
        let passwordID = actionRequestData.data.loginId
        
        guard let passwordData = passwordInteractor.getPassword(for: passwordID, checkInTrash: false) else {
            throw ConnectError.missingItem
        }
        
        let accepted = await shouldPerfromAction(.passwordRequest(passwordData)).accepted
        
        guard accepted else {
            throw ConnectError.cancelled
        }
        
        let passwordValue = {
            if let password = passwordData.password {
                return passwordInteractor.decrypt(password, isPassword: true, protectionLevel: passwordData.protectionLevel)
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
        
        return ConnectActionPasswordData(type: .passwordRequest, status: .accept, passwordEnc: passwordEnc)
    }
    
    private func handleUpdateLoginResponse(_ data: Data, keys: SessionKeys, shouldPerfromAction: (ConnectAction) async -> ConnectContinuation) async throws -> ConnectActionItemData {
        let actionRequestData = try mainRepository.jsonDecoder.decode(ConnectActionRequest<ConnectActionUpdateRequestData>.self, from: data)
        let passwordID = actionRequestData.data.id
        
        guard let passwordData = passwordInteractor.getPassword(for: passwordID, checkInTrash: false) else {
            throw ConnectError.missingItem
        }
        
        let encryptionPasswordKey: (PasswordProtectionLevel) -> SymmetricKey? = { protectionLevel in
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
        
        guard let protectionLevel = PasswordProtectionLevel(intValue: actionRequestData.data.securityType) else {
            throw ConnectError.badData
        }
        
        let newPassword: String?
        if let newPasswordDataEnc = actionRequestData.data.passwordEnc, let encryptionKey = encryptionPasswordKey(protectionLevel), let newPasswordData = mainRepository.decrypt(newPasswordDataEnc, key: encryptionKey) {
            newPassword = String(data: newPasswordData, encoding: .utf8)
        } else {
            newPassword = nil
        }
        
        let changeRequst = PasswordDataChangeRequest(
            name: actionRequestData.data.name,
            username: actionRequestData.data.username,
            password: actionRequestData.data.passwordMobile == true ? .generateNewPassword : newPassword.map { .value($0) },
            notes: actionRequestData.data.notes,
            protectionLevel: protectionLevel,
            uris: actionRequestData.data.uris?.compactMap {
                guard let match = PasswordURI.Match(intValue: $0.matcher) else {
                    return nil
                }
                return PasswordURI(uri: $0.text, match: match)
            }
        )
        
        let accepted = await shouldPerfromAction(.update(passwordData, changeRequst)).accepted
        
        guard accepted else {
            throw ConnectError.cancelled
        }
        
        guard let deviceID = mainRepository.deviceID else {
            throw ConnectError.missingDeviceId
        }
        
        let connectLogin = try await connectExportInteractor.preparePasswordForConnectExport(id: passwordID, encryptPasswordKey: encryptionPasswordKey, deviceId: deviceID)
        let actionData = ConnectActionItemData(
            type: .updateLogin,
            status: connectLogin.securityType == PasswordProtectionLevel.topSecret.intValue ? .addedInT1 : .updated,
            login: connectLogin
        )
        return actionData
    }
    
    private func handleDeleteLoginResponse(_ data: Data, keys: SessionKeys, shouldPerfromAction: (ConnectAction) async -> ConnectContinuation) async throws -> ConnectActionItemData {
        let actionRequestData = try mainRepository.jsonDecoder.decode(ConnectActionRequest<ConnectActionPasswordRequestData>.self, from: data)
        let passwordID = actionRequestData.data.loginId
        
        guard let passwordData = passwordInteractor.getPassword(for: passwordID, checkInTrash: false) else {
            throw ConnectError.missingItem
        }
        
        let accepted = await shouldPerfromAction(.delete(passwordData)).accepted
        
        guard accepted else {
            throw ConnectError.cancelled
        }
        
        return ConnectActionItemData(type: .deleteLogin, status: .accept, login: nil)
    }
    
    @MainActor
    private func webBrowser(for notification: AppNotification) -> WebBrowser? {
        guard let pkPersBe = Data(base64Encoded: notification.data.pkPersBe) else {
            return nil
        }
        
        let pkPersBeHex = pkPersBe.toHEXString()
        
        return webBrowsersInteractor.getWebBrowser(publicKey: pkPersBeHex)
    }
}
